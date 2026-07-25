import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_sync_payload.dart';
import 'package:rebirth/features/sync/domain/sync_conflict.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_adapter.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

import 'plan_local_data_source.dart';
import 'plan_sync_payload_codec.dart';

final class PlanSyncAdapter implements SyncEntityAdapter {
  PlanSyncAdapter(
    db.AppDatabase database, [
    this._conflictRepository,
    this._conflictScopeLoader,
    DateTimeService dateTimeService = const DateTimeService(),
  ]) : _database = database,
       _localDataSource = PlanLocalDataSource(database),
       _payloadCodec = PlanSyncPayloadCodec(dateTimeService);

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final db.AppDatabase _database;
  final PlanLocalDataSource _localDataSource;
  final SyncConflictRepository? _conflictRepository;
  final Future<SyncConflictScope?> Function()? _conflictScopeLoader;
  final PlanSyncPayloadCodec _payloadCodec;

  @override
  SyncEntityType get entityType => SyncEntityType.plan;

  @override
  Future<List<SyncPushItem>> collectPending() async {
    final context = await _loadContext();
    final all = await _localDataSource.selectAllForUser(userId: context.userId);
    final pending = all
        .where(
          (goal) =>
              goal.syncStatus == 'local_only' || goal.syncStatus == 'pending',
        )
        .toList(growable: false);
    if (pending.isEmpty) return const [];

    final byId = {for (final goal in all) goal.id: goal};
    _validateLocalHierarchy(byId);
    final depth = _buildDepthResolver(byId);
    final upserts = pending.where((goal) => goal.deletedAt == null).toList()
      ..sort((left, right) => _compareGoal(left, right, depth, false));
    final tombstones = pending.where((goal) => goal.deletedAt != null).toList()
      ..sort((left, right) => _compareGoal(left, right, depth, true));

    return [
      ...upserts.map((goal) => _upsertItem(goal, context)),
      ...tombstones.map((goal) => _deleteItem(goal, context)),
    ];
  }

  @override
  Map<String, Object?> encodePayload(SyncEntityPayload payload) {
    return _payloadCodec.encode(payload);
  }

  @override
  SyncChange decodeRemoteChange({
    required String recordId,
    required Map<String, Object?> payload,
    required int updatedAt,
    required int? deletedAt,
    required String originDeviceId,
    required int serverVersion,
  }) {
    if (!_isUuid(recordId)) {
      throw const SyncException('云端 Plan ID 不是合法 UUID。');
    }
    if (updatedAt < 0 ||
        serverVersion < 0 ||
        (deletedAt != null && deletedAt < 0)) {
      throw const SyncException('云端 Plan 版本或时间无效。');
    }
    if (!_isUuid(originDeviceId)) {
      throw const SyncException('云端 Plan 来源设备无效。');
    }
    final operation = deletedAt == null
        ? SyncOperation.upsert
        : SyncOperation.delete;
    if (operation == SyncOperation.delete && payload.isNotEmpty) {
      throw const SyncException('云端 Plan tombstone payload 必须为空。');
    }
    final typedPayload = operation == SyncOperation.upsert
        ? _payloadCodec.decode(recordId: recordId, json: payload)
        : null;
    return SyncChange(
      entityType: entityType,
      operation: operation,
      recordId: recordId,
      payload: typedPayload,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      originDeviceId: originDeviceId,
      serverVersion: serverVersion,
    );
  }

  @override
  Future<SyncEntityResult> acknowledgePush({
    required List<SyncPushItem> submitted,
    required List<SyncAcknowledgement> accepted,
    required List<SyncConflict> conflicts,
    required int syncedAt,
  }) {
    return _database.transaction(() async {
      final context = await _loadContext();
      final trueConflicts = conflicts
          .where((conflict) => conflict.reason != 'request_conflict')
          .toList(growable: false);
      final conflictScope = trueConflicts.isNotEmpty || accepted.isNotEmpty
          ? await _tryLoadConflictScope()
          : null;
      final submittedIds = <String>{};
      for (final item in submitted) {
        if (item.entityType != entityType || !submittedIds.add(item.recordId)) {
          throw const SyncException('Plan 上传上下文无效。');
        }
      }
      final responseIds = <String>{};
      for (final item in accepted) {
        if (item.entityType != entityType ||
            !submittedIds.contains(item.recordId) ||
            !responseIds.add(item.recordId)) {
          throw const SyncException('Plan 上传确认包含未提交或重复的记录。');
        }
      }
      for (final item in conflicts) {
        if (item.tableName != entityType.wireName ||
            !submittedIds.contains(item.recordId) ||
            !responseIds.add(item.recordId)) {
          throw const SyncException('Plan 冲突响应包含未提交或重复的记录。');
        }
      }
      if (responseIds.length != submittedIds.length) {
        throw const SyncException('Plan 上传响应不完整。');
      }

      for (final item in accepted) {
        final affected =
            await (_database.update(_database.goals)..where(
                  (row) =>
                      row.userId.equals(context.userId) &
                      row.id.equals(item.recordId),
                ))
                .write(
                  db.GoalsCompanion(
                    syncStatus: const Value('synced'),
                    serverVersion: Value(item.serverVersion),
                    lastSyncedAt: Value(syncedAt),
                  ),
                );
        if (affected != 1) {
          throw SyncException('找不到 Plan 上传记录 ${item.recordId}。');
        }
        if (conflictScope != null && _conflictRepository != null) {
          final conflict = await _conflictRepository.findActiveConflict(
            scope: conflictScope,
            entityType: entityType,
            recordId: item.recordId,
          );
          if (conflict?.resolutionStatus ==
              SyncConflictResolutionStatus.keepLocalRequested) {
            await _conflictRepository.markResolvedKeepLocal(
              conflictScope,
              conflict!.id,
              resolvedAt: syncedAt,
            );
          }
        }
      }
      for (final item in trueConflicts) {
        final goal = await _localDataSource.selectByIdIncludingDeleted(
          userId: context.userId,
          id: item.recordId,
        );
        if (goal == null) {
          throw SyncException('找不到 Plan 冲突记录 ${item.recordId}。');
        }
        if (conflictScope != null && _conflictRepository != null) {
          await _conflictRepository.upsertDetectedConflict(
            SyncConflictDetection(
              scope: conflictScope,
              entityType: entityType,
              recordId: item.recordId,
              localSnapshot: _localSnapshot(goal),
              remoteSnapshot: SyncConflictSnapshot(
                payload: null,
                updatedAt: null,
                deletedAt: null,
                serverVersion: item.serverVersion,
                originDeviceId: null,
              ),
              remoteOperation: SyncConflictOperation.unknownPendingPull,
              resolutionStatus:
                  SyncConflictResolutionStatus.awaitingRemoteSnapshot,
              detectedAt: syncedAt,
            ),
          );
        }
        final affected =
            await (_database.update(_database.goals)..where(
                  (row) =>
                      row.userId.equals(context.userId) &
                      row.id.equals(item.recordId),
                ))
                .write(const db.GoalsCompanion(syncStatus: Value('conflict')));
        if (affected != 1) {
          throw SyncException('找不到 Plan 冲突记录 ${item.recordId}。');
        }
      }
      return SyncEntityResult(
        entityType: entityType,
        status: trueConflicts.isEmpty
            ? SyncEntityStatus.succeeded
            : SyncEntityStatus.conflict,
        message: trueConflicts.isEmpty ? 'Plan 已上传' : 'Plan 上传存在版本冲突',
        pushedCount: accepted.length,
        conflictCount: trueConflicts.length,
        serverVersion: accepted.isEmpty
            ? null
            : accepted
                  .map((item) => item.serverVersion)
                  .reduce((left, right) => left > right ? left : right),
      );
    });
  }

  @override
  Future<SyncEntityResult> applyRemoteChanges({
    required List<SyncChange> changes,
    required int syncedAt,
  }) {
    return _database.transaction(() async {
      final context = await _loadContext();
      final all = await _localDataSource.selectAllForUser(
        userId: context.userId,
      );
      final byId = {for (final goal in all) goal.id: goal};
      final seen = <String>{};
      final applicable = <SyncChange>[];
      final localConflicts = <SyncChange>[];
      final adoptRemoteConflicts = <String, SyncConflictRecord>{};
      final conflictScope = changes.isEmpty
          ? null
          : await _tryLoadConflictScope();
      var ignored = 0;

      for (final change in changes) {
        if (change.entityType != entityType ||
            !_isUuid(change.recordId) ||
            !seen.add(change.recordId)) {
          throw const SyncException('云端 Plan 批次包含非法或重复记录。');
        }
        final validUpsert =
            change.operation == SyncOperation.upsert &&
            change.deletedAt == null &&
            change.payload is PlanSyncPayload;
        final validDelete =
            change.operation == SyncOperation.delete &&
            change.deletedAt != null &&
            change.deletedAt! >= 0 &&
            change.payload == null;
        if ((!validUpsert && !validDelete) ||
            change.updatedAt < 0 ||
            change.serverVersion < 0 ||
            !_isUuid(change.originDeviceId)) {
          throw const SyncException('云端 Plan 批次字段无效。');
        }
        if (validUpsert) {
          _payloadCodec.validate(
            recordId: change.recordId,
            payload: change.payload! as PlanSyncPayload,
          );
        }
        final local = byId[change.recordId];
        if (local != null &&
            change.serverVersion <= (local.serverVersion ?? 0) &&
            local.syncStatus != 'conflict') {
          ignored += 1;
          continue;
        }
        final activeConflict =
            conflictScope == null || _conflictRepository == null
            ? null
            : await _conflictRepository.findActiveConflict(
                scope: conflictScope,
                entityType: entityType,
                recordId: change.recordId,
              );
        if (activeConflict != null) {
          if (activeConflict.resolutionStatus ==
              SyncConflictResolutionStatus.adoptRemoteRequested) {
            final storedVersion =
                activeConflict.remoteSnapshot.serverVersion ?? 0;
            if (change.serverVersion < storedVersion) {
              localConflicts.add(change);
              continue;
            }
            final refreshed = await _conflictRepository!.hydrateRemoteSnapshot(
              scope: conflictScope!,
              entityType: entityType,
              recordId: change.recordId,
              operation: change.operation == SyncOperation.delete
                  ? SyncConflictOperation.delete
                  : SyncConflictOperation.upsert,
              remoteSnapshot: _remoteSnapshot(change),
              seenAt: syncedAt,
            );
            applicable.add(change);
            adoptRemoteConflicts[change.recordId] = refreshed;
            continue;
          }
          localConflicts.add(change);
          continue;
        }
        if (local != null && local.syncStatus != 'synced') {
          localConflicts.add(change);
          continue;
        }
        applicable.add(change);
      }

      _validateProjectedHierarchy(current: byId, changes: applicable);
      if (localConflicts.isNotEmpty) {
        for (final change in localConflicts) {
          final goal = byId[change.recordId];
          if (goal == null) {
            throw const SyncException('云端 Plan 冲突缺少本地记录。');
          }
          if (conflictScope != null && _conflictRepository != null) {
            final existing = await _conflictRepository.findActiveConflict(
              scope: conflictScope,
              entityType: entityType,
              recordId: change.recordId,
            );
            final operation = change.operation == SyncOperation.delete
                ? SyncConflictOperation.delete
                : SyncConflictOperation.upsert;
            final remoteSnapshot = _remoteSnapshot(change);
            if (existing == null) {
              await _conflictRepository.upsertDetectedConflict(
                SyncConflictDetection(
                  scope: conflictScope,
                  entityType: entityType,
                  recordId: change.recordId,
                  localSnapshot: _localSnapshot(goal),
                  remoteSnapshot: remoteSnapshot,
                  remoteOperation: operation,
                  resolutionStatus: SyncConflictResolutionStatus.unresolved,
                  detectedAt: syncedAt,
                ),
              );
            } else if (existing.resolutionStatus ==
                    SyncConflictResolutionStatus.awaitingRemoteSnapshot ||
                change.serverVersion >
                    (existing.remoteSnapshot.serverVersion ?? 0)) {
              await _conflictRepository.hydrateRemoteSnapshot(
                scope: conflictScope,
                entityType: entityType,
                recordId: change.recordId,
                operation: operation,
                remoteSnapshot: remoteSnapshot,
                seenAt: syncedAt,
              );
            } else {
              await _conflictRepository.upsertDetectedConflict(
                SyncConflictDetection(
                  scope: conflictScope,
                  entityType: entityType,
                  recordId: change.recordId,
                  localSnapshot: _localSnapshot(goal),
                  remoteSnapshot: remoteSnapshot,
                  remoteOperation: operation,
                  resolutionStatus: existing.resolutionStatus,
                  detectedAt: syncedAt,
                ),
              );
            }
          }
          await (_database.update(_database.goals)..where(
                (row) =>
                    row.userId.equals(context.userId) &
                    row.id.equals(change.recordId),
              ))
              .write(const db.GoalsCompanion(syncStatus: Value('conflict')));
        }
        return SyncEntityResult(
          entityType: entityType,
          status: SyncEntityStatus.conflict,
          message: '检测到 ${localConflicts.length} 个本地与云端 Plan 冲突，未覆盖本地内容',
          ignoredCount: ignored,
          conflictCount: localConflicts.length,
          serverVersion: localConflicts
              .map((change) => change.serverVersion)
              .reduce((left, right) => left > right ? left : right),
        );
      }

      final depth = _buildRemoteDepthResolver(byId, applicable);
      final upserts =
          applicable
              .where((change) => change.operation == SyncOperation.upsert)
              .toList()
            ..sort(
              (left, right) => _compareRemoteChange(left, right, depth, false),
            );
      final tombstones =
          applicable
              .where((change) => change.operation == SyncOperation.delete)
              .toList()
            ..sort(
              (left, right) => _compareRemoteChange(left, right, depth, true),
            );
      var applied = 0;
      var deleted = 0;

      for (final change in upserts) {
        final payload = change.payload;
        if (payload is! PlanSyncPayload) {
          throw const SyncException('云端 Plan payload 类型无效。');
        }
        final existing = byId[change.recordId];
        if (existing == null) {
          final global = await (_database.select(
            _database.goals,
          )..where((row) => row.id.equals(change.recordId))).getSingleOrNull();
          if (global != null) {
            throw const SyncException('云端 Plan ID 与其他本地用户冲突。');
          }
          await _database
              .into(_database.goals)
              .insert(
                db.GoalsCompanion.insert(
                  id: Value(change.recordId),
                  userId: context.userId,
                  parentGoalId: Value(payload.parentGoalId),
                  title: payload.title,
                  description: Value(payload.description),
                  goalLevel: payload.goalLevel.databaseValue,
                  status: Value(payload.status.databaseValue),
                  startDate: Value(payload.startDate),
                  targetDate: Value(payload.targetDate),
                  completedAt: Value(payload.completedAt),
                  archivedAt: Value(payload.archivedAt),
                  sortOrder: Value(payload.sortOrder),
                  createdAt: Value(payload.createdAt),
                  updatedAt: Value(change.updatedAt),
                  syncStatus: const Value('synced'),
                  serverVersion: Value(change.serverVersion),
                  lastSyncedAt: Value(syncedAt),
                  originDeviceId: Value(change.originDeviceId),
                  deletedAt: const Value(null),
                ),
              );
        } else {
          await (_database.update(_database.goals)..where(
                (row) =>
                    row.userId.equals(context.userId) &
                    row.id.equals(change.recordId),
              ))
              .write(
                db.GoalsCompanion(
                  parentGoalId: Value(payload.parentGoalId),
                  title: Value(payload.title),
                  description: Value(payload.description),
                  goalLevel: Value(payload.goalLevel.databaseValue),
                  status: Value(payload.status.databaseValue),
                  startDate: Value(payload.startDate),
                  targetDate: Value(payload.targetDate),
                  completedAt: Value(payload.completedAt),
                  archivedAt: Value(payload.archivedAt),
                  sortOrder: Value(payload.sortOrder),
                  createdAt: Value(payload.createdAt),
                  updatedAt: Value(change.updatedAt),
                  deletedAt: const Value(null),
                  syncStatus: const Value('synced'),
                  serverVersion: Value(change.serverVersion),
                  lastSyncedAt: Value(syncedAt),
                  originDeviceId: Value(change.originDeviceId),
                ),
              );
        }
        final resolvedConflict = adoptRemoteConflicts[change.recordId];
        if (resolvedConflict != null && conflictScope != null) {
          await _conflictRepository!.markResolvedAdoptRemote(
            conflictScope,
            resolvedConflict.id,
            resolvedAt: syncedAt,
          );
        }
        applied += 1;
      }

      for (final change in tombstones) {
        if (!byId.containsKey(change.recordId)) {
          ignored += 1;
          continue;
        }
        await (_database.update(_database.goals)..where(
              (row) =>
                  row.userId.equals(context.userId) &
                  row.id.equals(change.recordId),
            ))
            .write(
              db.GoalsCompanion(
                updatedAt: Value(change.updatedAt),
                deletedAt: Value(change.deletedAt),
                syncStatus: const Value('synced'),
                serverVersion: Value(change.serverVersion),
                lastSyncedAt: Value(syncedAt),
                originDeviceId: Value(change.originDeviceId),
              ),
            );
        final resolvedConflict = adoptRemoteConflicts[change.recordId];
        if (resolvedConflict != null && conflictScope != null) {
          await _conflictRepository!.markResolvedAdoptRemote(
            conflictScope,
            resolvedConflict.id,
            resolvedAt: syncedAt,
          );
        }
        applied += 1;
        deleted += 1;
      }

      return SyncEntityResult(
        entityType: entityType,
        status: applied == 0
            ? SyncEntityStatus.noChanges
            : SyncEntityStatus.succeeded,
        message: applied == 0 ? '没有新的 Plan 更新' : 'Plan 已更新',
        pulledCount: applied,
        deletedCount: deleted,
        ignoredCount: ignored,
        serverVersion: applicable.isEmpty
            ? null
            : applicable
                  .map((change) => change.serverVersion)
                  .reduce((left, right) => left > right ? left : right),
      );
    });
  }

  Future<_PlanLocalContext> _loadContext() async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    return _PlanLocalContext(
      userId: bootstrap.activeUserId,
      localInstallationId: bootstrap.localInstallationId,
    );
  }

  Future<SyncConflictScope?> _tryLoadConflictScope() async {
    final loader = _conflictScopeLoader;
    if (loader == null) return null;
    return loader();
  }

  SyncConflictSnapshot _localSnapshot(db.Goal goal) {
    return SyncConflictSnapshot(
      payload: goal.deletedAt == null ? _payloadFromGoal(goal) : null,
      updatedAt: goal.updatedAt,
      deletedAt: goal.deletedAt,
      serverVersion: goal.serverVersion,
      originDeviceId: goal.originDeviceId,
    );
  }

  SyncConflictSnapshot _remoteSnapshot(SyncChange change) {
    return SyncConflictSnapshot(
      payload: change.payload,
      updatedAt: change.updatedAt,
      deletedAt: change.deletedAt,
      serverVersion: change.serverVersion,
      originDeviceId: change.originDeviceId,
    );
  }

  PlanSyncPayload _payloadFromGoal(db.Goal goal) {
    return PlanSyncPayload(
      parentGoalId: goal.parentGoalId,
      title: goal.title,
      description: goal.description,
      goalLevel: planGoalLevelFromDatabase(goal.goalLevel),
      status: planGoalStatusFromDatabase(goal.status),
      startDate: goal.startDate,
      targetDate: goal.targetDate,
      completedAt: goal.completedAt,
      archivedAt: goal.archivedAt,
      sortOrder: goal.sortOrder,
      createdAt: goal.createdAt,
    );
  }

  SyncPushItem _upsertItem(db.Goal goal, _PlanLocalContext context) {
    final payload = _payloadFromGoal(goal);
    _payloadCodec.validate(recordId: goal.id, payload: payload);
    return _syncItem(
      goal: goal,
      context: context,
      operation: SyncOperation.upsert,
      payload: payload,
    );
  }

  SyncPushItem _deleteItem(db.Goal goal, _PlanLocalContext context) {
    if (goal.deletedAt == null || goal.deletedAt! < 0) {
      throw const SyncException('本地 Plan tombstone 时间无效。');
    }
    return _syncItem(
      goal: goal,
      context: context,
      operation: SyncOperation.delete,
      payload: null,
    );
  }

  SyncPushItem _syncItem({
    required db.Goal goal,
    required _PlanLocalContext context,
    required SyncOperation operation,
    required PlanSyncPayload? payload,
  }) {
    final originDeviceId = goal.originDeviceId ?? context.localInstallationId;
    if (!_isUuid(goal.id) || !_isUuid(originDeviceId)) {
      throw const SyncException('本地 Plan ID 或来源设备无效。');
    }
    return SyncPushItem(
      entityType: entityType,
      operation: operation,
      recordId: goal.id,
      payload: payload,
      updatedAt: goal.updatedAt,
      deletedAt: goal.deletedAt,
      originDeviceId: originDeviceId,
      clientVersion: goal.serverVersion ?? 0,
    );
  }

  void _validateLocalHierarchy(Map<String, db.Goal> byId) {
    for (final goal in byId.values) {
      final parentId = goal.parentGoalId;
      if (parentId != null && !byId.containsKey(parentId)) {
        throw SyncException('Plan ${goal.id} 的本地父目标不存在。');
      }
    }
    final depth = _buildDepthResolver(byId);
    for (final id in byId.keys) {
      depth(id);
    }
  }

  int Function(String) _buildDepthResolver(Map<String, db.Goal> byId) {
    final cache = <String, int>{};
    final visiting = <String>{};
    int depth(String id) {
      final cached = cache[id];
      if (cached != null) return cached;
      if (!visiting.add(id)) {
        throw const SyncException('本地 Plan 层级存在循环，无法上传。');
      }
      final goal = byId[id];
      if (goal == null) {
        throw SyncException('本地 Plan 缺少目标 $id。');
      }
      final result = goal.parentGoalId == null
          ? 0
          : depth(goal.parentGoalId!) + 1;
      visiting.remove(id);
      cache[id] = result;
      return result;
    }

    return depth;
  }

  int _compareGoal(
    db.Goal left,
    db.Goal right,
    int Function(String) depth,
    bool descendingDepth,
  ) {
    final depthComparison = depth(left.id).compareTo(depth(right.id));
    if (depthComparison != 0) {
      return descendingDepth ? -depthComparison : depthComparison;
    }
    final sortComparison = left.sortOrder.compareTo(right.sortOrder);
    if (sortComparison != 0) return sortComparison;
    final createdComparison = left.createdAt.compareTo(right.createdAt);
    if (createdComparison != 0) return createdComparison;
    return left.id.compareTo(right.id);
  }

  void _validateProjectedHierarchy({
    required Map<String, db.Goal> current,
    required List<SyncChange> changes,
  }) {
    final parents = <String, String?>{
      for (final goal in current.values)
        if (goal.deletedAt == null) goal.id: goal.parentGoalId,
    };
    for (final change in changes) {
      if (change.operation == SyncOperation.delete) {
        parents.remove(change.recordId);
      } else {
        final payload = change.payload;
        if (payload is! PlanSyncPayload) {
          throw const SyncException('云端 Plan payload 类型无效。');
        }
        parents[change.recordId] = payload.parentGoalId;
      }
    }
    for (final entry in parents.entries) {
      if (entry.value != null && !parents.containsKey(entry.value)) {
        throw SyncException('云端 Plan ${entry.key} 引用了不存在的父目标。');
      }
    }
    final visiting = <String>{};
    final visited = <String>{};
    void visit(String id) {
      if (visited.contains(id)) return;
      if (!visiting.add(id)) {
        throw const SyncException('云端 Plan 层级存在循环。');
      }
      final parentId = parents[id];
      if (parentId != null) visit(parentId);
      visiting.remove(id);
      visited.add(id);
    }

    for (final id in parents.keys) {
      visit(id);
    }
  }

  int Function(String) _buildRemoteDepthResolver(
    Map<String, db.Goal> current,
    List<SyncChange> changes,
  ) {
    final parents = {
      for (final goal in current.values) goal.id: goal.parentGoalId,
    };
    for (final change in changes) {
      final payload = change.payload;
      if (payload is PlanSyncPayload) {
        parents[change.recordId] = payload.parentGoalId;
      }
    }
    final cache = <String, int>{};
    int depth(String id) {
      final cached = cache[id];
      if (cached != null) return cached;
      final parentId = parents[id];
      final result = parentId == null ? 0 : depth(parentId) + 1;
      cache[id] = result;
      return result;
    }

    return depth;
  }

  int _compareRemoteChange(
    SyncChange left,
    SyncChange right,
    int Function(String) depth,
    bool descendingDepth,
  ) {
    final comparison = depth(left.recordId).compareTo(depth(right.recordId));
    if (comparison != 0) {
      return descendingDepth ? -comparison : comparison;
    }
    return left.serverVersion.compareTo(right.serverVersion);
  }

  static bool _isUuid(String value) => _uuidPattern.hasMatch(value);
}

final class _PlanLocalContext {
  const _PlanLocalContext({
    required this.userId,
    required this.localInstallationId,
  });

  final String userId;
  final String localInstallationId;
}
