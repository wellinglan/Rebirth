import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/features/sync/domain/sync_conflict.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_adapter.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_sync_payload.dart';

import 'today_sync_payload_codec.dart';

final class TodaySyncAdapter implements SyncEntityAdapter {
  TodaySyncAdapter(
    this._database, [
    this._conflictRepository,
    this._conflictScopeLoader,
    this._payloadCodec = const TodaySyncPayloadCodec(),
  ]);

  final db.AppDatabase _database;
  final SyncConflictRepository? _conflictRepository;
  final Future<SyncConflictScope?> Function()? _conflictScopeLoader;
  final TodaySyncPayloadCodec _payloadCodec;

  @override
  SyncEntityType get entityType => SyncEntityType.today;

  @override
  Future<List<SyncPushItem>> collectPending() async {
    final context = await _loadContext();
    final rows =
        await (_database.select(_database.todayRecords)..where(
              (row) =>
                  row.userId.equals(context.userId) &
                  row.syncStatus.isIn(const ['local_only', 'pending']),
            ))
            .get();
    final pending =
        rows
            .where(
              (row) =>
                  row.deletedAt != null ||
                  row.syncStatus == 'pending' ||
                  _hasBusinessContent(row),
            )
            .toList(growable: false)
          ..sort((left, right) {
            final date = left.recordDate.compareTo(right.recordDate);
            return date != 0 ? date : left.id.compareTo(right.id);
          });

    return pending
        .map((row) {
          final originDeviceId =
              row.originDeviceId ?? context.localInstallationId;
          if (!TodaySyncPayloadCodec.isUuid(row.id) ||
              !TodaySyncPayloadCodec.isUuid(originDeviceId)) {
            throw const SyncException('本地 Today ID 或来源设备无效。');
          }
          final deletedAt = row.deletedAt;
          if (deletedAt != null && deletedAt < 0) {
            throw const SyncException('本地 Today tombstone 时间无效。');
          }
          final payload = deletedAt == null ? _payloadFromRecord(row) : null;
          if (payload != null) _payloadCodec.validate(payload);
          return SyncPushItem(
            entityType: entityType,
            operation: deletedAt == null
                ? SyncOperation.upsert
                : SyncOperation.delete,
            recordId: row.id,
            payload: payload,
            updatedAt: row.updatedAt,
            deletedAt: deletedAt,
            originDeviceId: originDeviceId,
            clientVersion: row.serverVersion ?? 0,
          );
        })
        .toList(growable: false);
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
    if (!TodaySyncPayloadCodec.isUuid(recordId) ||
        !TodaySyncPayloadCodec.isUuid(originDeviceId) ||
        updatedAt < 0 ||
        serverVersion < 0 ||
        (deletedAt != null && deletedAt < 0)) {
      throw const SyncException('云端 Today 同步元数据无效。');
    }
    final operation = deletedAt == null
        ? SyncOperation.upsert
        : SyncOperation.delete;
    if (operation == SyncOperation.delete && payload.isNotEmpty) {
      throw const SyncException('云端 Today tombstone payload 必须为空。');
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
      final submittedIds = <String>{};
      for (final item in submitted) {
        if (item.entityType != entityType || !submittedIds.add(item.recordId)) {
          throw const SyncException('Today 上传上下文无效。');
        }
      }
      final responseIds = <String>{};
      for (final item in accepted) {
        if (item.entityType != entityType ||
            !submittedIds.contains(item.recordId) ||
            !responseIds.add(item.recordId)) {
          throw const SyncException('Today 上传确认包含未提交或重复的记录。');
        }
      }
      for (final item in conflicts) {
        if (item.tableName != entityType.wireName ||
            !submittedIds.contains(item.recordId) ||
            !responseIds.add(item.recordId)) {
          throw const SyncException('Today 冲突响应包含未提交或重复的记录。');
        }
      }
      if (responseIds.length != submittedIds.length) {
        throw const SyncException('Today 上传响应不完整。');
      }

      final trueConflicts = conflicts
          .where((item) => item.reason != 'request_conflict')
          .toList(growable: false);
      final conflictScope = trueConflicts.isNotEmpty
          ? await _tryLoadConflictScope()
          : null;

      for (final item in accepted) {
        final affected =
            await (_database.update(_database.todayRecords)..where(
                  (row) =>
                      row.userId.equals(context.userId) &
                      row.id.equals(item.recordId),
                ))
                .write(
                  db.TodayRecordsCompanion(
                    syncStatus: const Value('synced'),
                    serverVersion: Value(item.serverVersion),
                    lastSyncedAt: Value(syncedAt),
                  ),
                );
        if (affected != 1) {
          throw SyncException('找不到 Today 上传记录 ${item.recordId}。');
        }
      }

      for (final item in trueConflicts) {
        final local = await _selectById(
          userId: context.userId,
          id: item.recordId,
        );
        if (local == null) {
          throw SyncException('找不到 Today 冲突记录 ${item.recordId}。');
        }
        if (conflictScope != null && _conflictRepository != null) {
          await _conflictRepository.upsertDetectedConflict(
            SyncConflictDetection(
              scope: conflictScope,
              entityType: entityType,
              recordId: local.id,
              localSnapshot: _localSnapshot(local),
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
        await (_database.update(_database.todayRecords)..where(
              (row) =>
                  row.userId.equals(context.userId) & row.id.equals(local.id),
            ))
            .write(
              const db.TodayRecordsCompanion(syncStatus: Value('conflict')),
            );
      }

      final versions = <int>[
        ...accepted.map((item) => item.serverVersion),
        ...trueConflicts.map((item) => item.serverVersion),
      ];
      return SyncEntityResult(
        entityType: entityType,
        status: trueConflicts.isEmpty
            ? accepted.isEmpty
                  ? SyncEntityStatus.noChanges
                  : SyncEntityStatus.succeeded
            : SyncEntityStatus.conflict,
        message: trueConflicts.isEmpty
            ? accepted.isEmpty
                  ? '没有需要上传的 Today 更新'
                  : 'Today 已上传'
            : 'Today 上传存在版本冲突，本地内容已保留',
        pushedCount: accepted.length,
        conflictCount: trueConflicts.length,
        serverVersion: versions.isEmpty
            ? null
            : versions.reduce((left, right) => left > right ? left : right),
      );
    });
  }

  @override
  Future<SyncEntityResult> applyRemoteChanges({
    required List<SyncChange> changes,
    required int syncedAt,
    SyncPullMode pullMode = SyncPullMode.incremental,
  }) {
    if (pullMode != SyncPullMode.incremental) {
      throw const SyncException('Today 尚不支持覆盖式冲突解决。');
    }
    return _database.transaction(() async {
      final context = await _loadContext();
      final current = await (_database.select(
        _database.todayRecords,
      )..where((row) => row.userId.equals(context.userId))).get();
      final byId = {for (final row in current) row.id: row};
      final activeByDate = {
        for (final row in current)
          if (row.deletedAt == null) row.recordDate: row,
      };
      final applicable = <SyncChange>[];
      final conflicts = <_TodayConflictCandidate>[];
      final replaceablePlaceholders = <String>{};
      final seenIds = <String>{};
      final seenUpsertDates = <String>{};
      final conflictScope = changes.isEmpty
          ? null
          : await _tryLoadConflictScope();
      var ignored = 0;

      for (final change in changes) {
        _validateChange(change, seenIds);
        final payload = change.payload;
        if (payload is TodaySyncPayload &&
            !seenUpsertDates.add(payload.recordDate)) {
          throw const SyncException('云端 Today 批次包含重复自然日。');
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
                recordId: local?.id ?? change.recordId,
              );
        if (activeConflict != null) {
          final localForConflict = local ?? byId[activeConflict.recordId];
          if (localForConflict == null) {
            throw const SyncException('Today 冲突缺少本地记录。');
          }
          await _hydrateConflictIfNewer(
            scope: conflictScope!,
            active: activeConflict,
            change: change,
            seenAt: syncedAt,
          );
          conflicts.add(
            _TodayConflictCandidate(change: change, local: localForConflict),
          );
          continue;
        }

        if (local != null && local.syncStatus != 'synced') {
          conflicts.add(_TodayConflictCandidate(change: change, local: local));
          continue;
        }

        if (payload is TodaySyncPayload) {
          final dateOwner = activeByDate[payload.recordDate];
          if (dateOwner != null && dateOwner.id != change.recordId) {
            if (await _isReplaceablePlaceholder(dateOwner)) {
              replaceablePlaceholders.add(dateOwner.id);
            } else {
              conflicts.add(
                _TodayConflictCandidate(change: change, local: dateOwner),
              );
              continue;
            }
          }
        }
        applicable.add(change);
      }

      if (conflicts.isNotEmpty) {
        for (final candidate in conflicts) {
          await _recordConflict(
            scope: conflictScope,
            candidate: candidate,
            detectedAt: syncedAt,
          );
          await (_database.update(_database.todayRecords)..where(
                (row) =>
                    row.userId.equals(context.userId) &
                    row.id.equals(candidate.local.id),
              ))
              .write(
                const db.TodayRecordsCompanion(syncStatus: Value('conflict')),
              );
        }
        return SyncEntityResult(
          entityType: entityType,
          status: SyncEntityStatus.conflict,
          message: '检测到 ${conflicts.length} 个 Today 冲突，本地内容未被覆盖',
          ignoredCount: ignored,
          conflictCount: conflicts.length,
          serverVersion: conflicts
              .map((item) => item.change.serverVersion)
              .reduce((left, right) => left > right ? left : right),
        );
      }

      _validateProjectedDates(
        current: current,
        changes: applicable,
        replaceablePlaceholders: replaceablePlaceholders,
      );
      var applied = 0;
      var deleted = 0;
      for (final change in applicable) {
        if (change.operation == SyncOperation.delete) {
          final local = byId[change.recordId];
          if (local == null) {
            ignored += 1;
            continue;
          }
          await (_database.update(_database.todayRecords)..where(
                (row) =>
                    row.userId.equals(context.userId) &
                    row.id.equals(change.recordId),
              ))
              .write(
                db.TodayRecordsCompanion(
                  updatedAt: Value(change.updatedAt),
                  deletedAt: Value(change.deletedAt),
                  syncStatus: const Value('synced'),
                  serverVersion: Value(change.serverVersion),
                  lastSyncedAt: Value(syncedAt),
                  originDeviceId: Value(change.originDeviceId),
                ),
              );
          applied += 1;
          deleted += 1;
          continue;
        }

        final payload = change.payload;
        if (payload is! TodaySyncPayload) {
          throw const SyncException('云端 Today payload 类型无效。');
        }
        await _validateGoalReferences(context.userId, payload);
        final placeholder = activeByDate[payload.recordDate];
        if (placeholder != null &&
            placeholder.id != change.recordId &&
            replaceablePlaceholders.contains(placeholder.id)) {
          await (_database.delete(_database.todayRecords)..where(
                (row) =>
                    row.userId.equals(context.userId) &
                    row.id.equals(placeholder.id),
              ))
              .go();
        }

        final existing = byId[change.recordId];
        if (existing == null) {
          final global = await (_database.select(
            _database.todayRecords,
          )..where((row) => row.id.equals(change.recordId))).getSingleOrNull();
          if (global != null) {
            throw const SyncException('云端 Today ID 与其他本地用户冲突。');
          }
          await _database
              .into(_database.todayRecords)
              .insert(
                db.TodayRecordsCompanion.insert(
                  id: Value(change.recordId),
                  userId: context.userId,
                  recordDate: payload.recordDate,
                  timezoneOffsetMinutes: payload.timezoneOffsetMinutes,
                  priority1: Value(payload.priority1),
                  priority1Completed: Value(payload.priority1Completed),
                  priority1GoalId: Value(payload.priority1GoalId),
                  priority2: Value(payload.priority2),
                  priority2Completed: Value(payload.priority2Completed),
                  priority2GoalId: Value(payload.priority2GoalId),
                  priority3: Value(payload.priority3),
                  priority3Completed: Value(payload.priority3Completed),
                  priority3GoalId: Value(payload.priority3GoalId),
                  moodScore: Value(payload.moodScore),
                  energyScore: Value(payload.energyScore),
                  researchMinutes: Value(payload.researchMinutes),
                  learningMinutes: Value(payload.learningMinutes),
                  dailyNote: Value(payload.dailyNote),
                  recordStatus: Value(payload.status.name),
                  createdAt: Value(payload.createdAt),
                  updatedAt: Value(change.updatedAt),
                  deletedAt: const Value(null),
                  syncStatus: const Value('synced'),
                  serverVersion: Value(change.serverVersion),
                  lastSyncedAt: Value(syncedAt),
                  originDeviceId: Value(change.originDeviceId),
                ),
              );
        } else {
          await (_database.update(_database.todayRecords)..where(
                (row) =>
                    row.userId.equals(context.userId) &
                    row.id.equals(change.recordId),
              ))
              .write(
                db.TodayRecordsCompanion(
                  recordDate: Value(payload.recordDate),
                  timezoneOffsetMinutes: Value(payload.timezoneOffsetMinutes),
                  priority1: Value(payload.priority1),
                  priority1Completed: Value(payload.priority1Completed),
                  priority1GoalId: Value(payload.priority1GoalId),
                  priority2: Value(payload.priority2),
                  priority2Completed: Value(payload.priority2Completed),
                  priority2GoalId: Value(payload.priority2GoalId),
                  priority3: Value(payload.priority3),
                  priority3Completed: Value(payload.priority3Completed),
                  priority3GoalId: Value(payload.priority3GoalId),
                  moodScore: Value(payload.moodScore),
                  energyScore: Value(payload.energyScore),
                  researchMinutes: Value(payload.researchMinutes),
                  learningMinutes: Value(payload.learningMinutes),
                  dailyNote: Value(payload.dailyNote),
                  recordStatus: Value(payload.status.name),
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
        applied += 1;
      }

      return SyncEntityResult(
        entityType: entityType,
        status: applied == 0
            ? SyncEntityStatus.noChanges
            : SyncEntityStatus.succeeded,
        message: applied == 0 ? '没有新的 Today 更新' : 'Today 已更新',
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

  Future<_TodayLocalContext> _loadContext() async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    return _TodayLocalContext(
      userId: bootstrap.activeUserId,
      localInstallationId: bootstrap.localInstallationId,
    );
  }

  Future<SyncConflictScope?> _tryLoadConflictScope() async {
    return _conflictScopeLoader?.call();
  }

  Future<db.TodayRecord?> _selectById({
    required String userId,
    required String id,
  }) {
    return (_database.select(_database.todayRecords)
          ..where((row) => row.userId.equals(userId) & row.id.equals(id)))
        .getSingleOrNull();
  }

  void _validateChange(SyncChange change, Set<String> seenIds) {
    if (change.entityType != entityType ||
        !TodaySyncPayloadCodec.isUuid(change.recordId) ||
        !TodaySyncPayloadCodec.isUuid(change.originDeviceId) ||
        !seenIds.add(change.recordId) ||
        change.updatedAt < 0 ||
        change.serverVersion < 0) {
      throw const SyncException('云端 Today 批次包含非法或重复记录。');
    }
    final validUpsert =
        change.operation == SyncOperation.upsert &&
        change.deletedAt == null &&
        change.payload is TodaySyncPayload;
    final validDelete =
        change.operation == SyncOperation.delete &&
        change.deletedAt != null &&
        change.deletedAt! >= 0 &&
        change.payload == null;
    if (!validUpsert && !validDelete) {
      throw const SyncException('云端 Today 操作字段不一致。');
    }
    if (change.payload case final TodaySyncPayload payload) {
      _payloadCodec.validate(payload);
    }
  }

  Future<void> _recordConflict({
    required SyncConflictScope? scope,
    required _TodayConflictCandidate candidate,
    required int detectedAt,
  }) async {
    if (scope == null || _conflictRepository == null) return;
    final existing = await _conflictRepository.findActiveConflict(
      scope: scope,
      entityType: entityType,
      recordId: candidate.local.id,
    );
    final operation = candidate.change.operation == SyncOperation.delete
        ? SyncConflictOperation.delete
        : SyncConflictOperation.upsert;
    final remoteSnapshot = _remoteSnapshot(candidate.change);
    if (existing == null) {
      await _conflictRepository.upsertDetectedConflict(
        SyncConflictDetection(
          scope: scope,
          entityType: entityType,
          recordId: candidate.local.id,
          localSnapshot: _localSnapshot(candidate.local),
          remoteSnapshot: remoteSnapshot,
          remoteOperation: operation,
          resolutionStatus: SyncConflictResolutionStatus.unresolved,
          detectedAt: detectedAt,
        ),
      );
      return;
    }
    await _hydrateConflictIfNewer(
      scope: scope,
      active: existing,
      change: candidate.change,
      seenAt: detectedAt,
    );
  }

  Future<void> _hydrateConflictIfNewer({
    required SyncConflictScope scope,
    required SyncConflictRecord active,
    required SyncChange change,
    required int seenAt,
  }) async {
    if (_conflictRepository == null ||
        change.serverVersion < (active.remoteSnapshot.serverVersion ?? 0)) {
      return;
    }
    await _conflictRepository.hydrateRemoteSnapshot(
      scope: scope,
      entityType: entityType,
      recordId: active.recordId,
      operation: change.operation == SyncOperation.delete
          ? SyncConflictOperation.delete
          : SyncConflictOperation.upsert,
      remoteSnapshot: _remoteSnapshot(change),
      seenAt: seenAt,
    );
  }

  void _validateProjectedDates({
    required List<db.TodayRecord> current,
    required List<SyncChange> changes,
    required Set<String> replaceablePlaceholders,
  }) {
    final dateById = {
      for (final row in current)
        if (row.deletedAt == null && !replaceablePlaceholders.contains(row.id))
          row.id: row.recordDate,
    };
    final ownerByDate = {
      for (final entry in dateById.entries) entry.value: entry.key,
    };
    final ordered = changes.toList(
      growable: false,
    )..sort((left, right) => left.serverVersion.compareTo(right.serverVersion));
    for (final change in ordered) {
      final oldDate = dateById.remove(change.recordId);
      if (oldDate != null) ownerByDate.remove(oldDate);
      if (change.operation == SyncOperation.delete) continue;
      final payload = change.payload! as TodaySyncPayload;
      final owner = ownerByDate[payload.recordDate];
      if (owner != null && owner != change.recordId) {
        throw const SyncException('云端 Today 自然日与本地记录冲突。');
      }
      dateById[change.recordId] = payload.recordDate;
      ownerByDate[payload.recordDate] = change.recordId;
    }
  }

  Future<void> _validateGoalReferences(
    String userId,
    TodaySyncPayload payload,
  ) async {
    final goalIds = {
      payload.priority1GoalId,
      payload.priority2GoalId,
      payload.priority3GoalId,
    }.whereType<String>().toSet();
    if (goalIds.isEmpty) return;
    final goals =
        await (_database.select(_database.goals)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.id.isIn(goalIds) &
                  row.deletedAt.isNull(),
            ))
            .get();
    if (goals.length != goalIds.length) {
      throw const SyncException('云端 Today 引用了当前账号不存在的 Plan 目标。');
    }
  }

  Future<bool> _isReplaceablePlaceholder(db.TodayRecord row) async {
    if (row.syncStatus != 'local_only' ||
        row.serverVersion != null ||
        row.deletedAt != null ||
        _hasBusinessContent(row)) {
      return false;
    }
    final linkedHealth =
        await (_database.select(_database.healthRecords)
              ..where((health) => health.todayRecordId.equals(row.id)))
            .getSingleOrNull();
    return linkedHealth == null;
  }

  bool _hasBusinessContent(db.TodayRecord row) {
    return row.priority1 != null ||
        row.priority1GoalId != null ||
        row.priority1Completed ||
        row.priority2 != null ||
        row.priority2GoalId != null ||
        row.priority2Completed ||
        row.priority3 != null ||
        row.priority3GoalId != null ||
        row.priority3Completed ||
        row.moodScore != null ||
        row.energyScore != null ||
        row.researchMinutes != null ||
        row.learningMinutes != null ||
        row.dailyNote != null ||
        row.recordStatus == TodayRecordStatus.completed.name;
  }

  TodaySyncPayload _payloadFromRecord(db.TodayRecord row) {
    return TodaySyncPayload(
      recordDate: row.recordDate,
      timezoneOffsetMinutes: row.timezoneOffsetMinutes,
      priority1: row.priority1,
      priority1Completed: row.priority1Completed,
      priority1GoalId: row.priority1GoalId,
      priority2: row.priority2,
      priority2Completed: row.priority2Completed,
      priority2GoalId: row.priority2GoalId,
      priority3: row.priority3,
      priority3Completed: row.priority3Completed,
      priority3GoalId: row.priority3GoalId,
      moodScore: row.moodScore,
      energyScore: row.energyScore,
      researchMinutes: row.researchMinutes,
      learningMinutes: row.learningMinutes,
      dailyNote: row.dailyNote,
      status: switch (row.recordStatus) {
        'draft' => TodayRecordStatus.draft,
        'completed' => TodayRecordStatus.completed,
        _ => throw const SyncException('本地 Today 状态无效。'),
      },
      createdAt: row.createdAt,
    );
  }

  SyncConflictSnapshot _localSnapshot(db.TodayRecord row) {
    return SyncConflictSnapshot(
      payload: row.deletedAt == null ? _payloadFromRecord(row) : null,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      serverVersion: row.serverVersion,
      originDeviceId: row.originDeviceId,
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
}

final class _TodayLocalContext {
  const _TodayLocalContext({
    required this.userId,
    required this.localInstallationId,
  });

  final String userId;
  final String localInstallationId;
}

final class _TodayConflictCandidate {
  const _TodayConflictCandidate({required this.change, required this.local});

  final SyncChange change;
  final db.TodayRecord local;
}
