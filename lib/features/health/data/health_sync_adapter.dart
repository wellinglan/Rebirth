import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/features/health/domain/health_sync_payload.dart';
import 'package:rebirth/features/sync/domain/sync_conflict.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_adapter.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

import 'health_sync_payload_codec.dart';

final class HealthSyncAdapter implements SyncEntityAdapter {
  HealthSyncAdapter(
    this._database, [
    this._conflictRepository,
    this._conflictScopeLoader,
    this._payloadCodec = const HealthSyncPayloadCodec(),
  ]);

  final db.AppDatabase _database;
  final SyncConflictRepository? _conflictRepository;
  final Future<SyncConflictScope?> Function()? _conflictScopeLoader;
  final HealthSyncPayloadCodec _payloadCodec;

  @override
  SyncEntityType get entityType => SyncEntityType.health;

  @override
  Future<List<SyncPushItem>> collectPending() async {
    final context = await _loadContext();
    final rows =
        await (_database.select(_database.healthRecords)..where(
              (row) =>
                  row.userId.equals(context.userId) &
                  row.syncStatus.isIn(const ['local_only', 'pending']),
            ))
            .get();
    rows.sort((left, right) {
      final date = left.recordDate.compareTo(right.recordDate);
      return date != 0 ? date : left.id.compareTo(right.id);
    });

    final pending = <SyncPushItem>[];
    for (final row in rows) {
      if (row.deletedAt == null &&
          row.syncStatus == 'local_only' &&
          !_hasMetrics(row)) {
        continue;
      }
      final originDeviceId = row.originDeviceId ?? context.localInstallationId;
      if (!HealthSyncPayloadCodec.isUuid(row.id) ||
          !HealthSyncPayloadCodec.isUuid(originDeviceId)) {
        throw const SyncException('本地 Health ID 或来源设备无效。');
      }
      if (row.deletedAt case final deletedAt? when deletedAt < 0) {
        throw const SyncException('本地 Health tombstone 时间无效。');
      }
      final payload = row.deletedAt == null ? _payloadFromRecord(row) : null;
      if (payload != null) _payloadCodec.validate(payload);
      pending.add(
        SyncPushItem(
          entityType: entityType,
          operation: row.deletedAt == null
              ? SyncOperation.upsert
              : SyncOperation.delete,
          recordId: row.id,
          payload: payload,
          updatedAt: row.updatedAt,
          deletedAt: row.deletedAt,
          originDeviceId: originDeviceId,
          clientVersion: row.serverVersion ?? 0,
        ),
      );
    }
    return pending;
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
    if (!HealthSyncPayloadCodec.isUuid(recordId) ||
        !HealthSyncPayloadCodec.isUuid(originDeviceId) ||
        updatedAt < 0 ||
        serverVersion < 0 ||
        (deletedAt != null && deletedAt < 0)) {
      throw const SyncException('云端 Health 同步元数据无效。');
    }
    final operation = deletedAt == null
        ? SyncOperation.upsert
        : SyncOperation.delete;
    if (operation == SyncOperation.delete && payload.isNotEmpty) {
      throw const SyncException('云端 Health tombstone payload 必须为空。');
    }
    return SyncChange(
      entityType: entityType,
      operation: operation,
      recordId: recordId,
      payload: operation == SyncOperation.upsert
          ? _payloadCodec.decode(recordId: recordId, json: payload)
          : null,
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
          throw const SyncException('Health 上传上下文无效。');
        }
      }
      final responseIds = <String>{};
      for (final item in accepted) {
        if (item.entityType != entityType ||
            !submittedIds.contains(item.recordId) ||
            !responseIds.add(item.recordId)) {
          throw const SyncException('Health 上传确认包含未提交或重复记录。');
        }
      }
      for (final item in conflicts) {
        if (item.tableName != entityType.wireName ||
            !submittedIds.contains(item.recordId) ||
            !responseIds.add(item.recordId)) {
          throw const SyncException('Health 冲突响应包含未提交或重复记录。');
        }
      }
      if (responseIds.length != submittedIds.length) {
        throw const SyncException('Health 上传响应不完整。');
      }

      final trueConflicts = conflicts
          .where((item) => item.reason != 'request_conflict')
          .toList(growable: false);
      final scope = accepted.isNotEmpty || trueConflicts.isNotEmpty
          ? await _tryLoadConflictScope()
          : null;

      for (final item in accepted) {
        final affected =
            await (_database.update(_database.healthRecords)..where(
                  (row) =>
                      row.userId.equals(context.userId) &
                      row.id.equals(item.recordId),
                ))
                .write(
                  db.HealthRecordsCompanion(
                    syncStatus: const Value('synced'),
                    serverVersion: Value(item.serverVersion),
                    lastSyncedAt: Value(syncedAt),
                  ),
                );
        if (affected != 1) {
          throw SyncException('找不到 Health 上传记录 ${item.recordId}。');
        }
        if (scope != null && _conflictRepository != null) {
          final conflict =
              await _conflictRepository.findActiveConflict(
                scope: scope,
                entityType: entityType,
                recordId: item.recordId,
              ) ??
              await _conflictRepository.findActiveConflictByRemoteRecordId(
                scope: scope,
                entityType: entityType,
                remoteRecordId: item.recordId,
              );
          if (conflict?.resolutionStatus ==
              SyncConflictResolutionStatus.keepLocalRequested) {
            await _conflictRepository.markResolvedKeepLocal(
              scope,
              conflict!.id,
              resolvedAt: syncedAt,
            );
          }
        }
      }

      for (final item in trueConflicts) {
        final local = await _selectById(
          userId: context.userId,
          id: item.recordId,
        );
        if (local == null) {
          throw SyncException('找不到 Health 冲突记录 ${item.recordId}。');
        }
        if (scope != null && _conflictRepository != null) {
          await _conflictRepository.upsertDetectedConflict(
            SyncConflictDetection(
              scope: scope,
              entityType: entityType,
              recordId: local.id,
              remoteRecordId: item.remoteRecordId ?? local.id,
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
        await (_database.update(_database.healthRecords)..where(
              (row) =>
                  row.userId.equals(context.userId) & row.id.equals(local.id),
            ))
            .write(
              const db.HealthRecordsCompanion(syncStatus: Value('conflict')),
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
                  ? '没有需要上传的 Health 更新'
                  : 'Health 已上传'
            : 'Health 上传存在版本冲突，本地内容已保留',
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
    return _database.transaction(() async {
      final context = await _loadContext();
      final current = await (_database.select(
        _database.healthRecords,
      )..where((row) => row.userId.equals(context.userId))).get();
      final byId = {for (final row in current) row.id: row};
      final activeByDate = {
        for (final row in current)
          if (row.deletedAt == null) row.recordDate: row,
      };
      final applicable = <SyncChange>[];
      final conflicts = <_HealthConflictCandidate>[];
      final adopted = <String, SyncConflictRecord>{};
      final seenIds = <String>{};
      final seenDates = <String>{};
      final scope = changes.isEmpty ? null : await _tryLoadConflictScope();
      var ignored = 0;

      for (final change in changes) {
        _validateChange(change, seenIds);
        final payload = change.payload;
        if (payload is HealthSyncPayload &&
            !seenDates.add(payload.recordDate)) {
          throw const SyncException('云端 Health 批次包含重复自然日。');
        }
        final local = byId[change.recordId];
        if (local != null &&
            change.serverVersion <= (local.serverVersion ?? 0) &&
            local.syncStatus != 'conflict') {
          ignored += 1;
          continue;
        }

        var activeConflict = scope == null || _conflictRepository == null
            ? null
            : await _conflictRepository.findActiveConflict(
                scope: scope,
                entityType: entityType,
                recordId: local?.id ?? change.recordId,
              );
        if (activeConflict == null &&
            scope != null &&
            _conflictRepository != null) {
          activeConflict = await _conflictRepository
              .findActiveConflictByRemoteRecordId(
                scope: scope,
                entityType: entityType,
                remoteRecordId: change.recordId,
              );
        }
        if (activeConflict != null) {
          final localForConflict = local ?? byId[activeConflict.recordId];
          if (localForConflict == null) {
            throw const SyncException('Health 冲突缺少本地记录。');
          }
          final refreshed = await _hydrateConflictIfNewer(
            scope: scope!,
            active: activeConflict,
            change: change,
            seenAt: syncedAt,
          );
          if (pullMode == SyncPullMode.preferRemoteConflictResolution &&
              refreshed.resolutionStatus ==
                  SyncConflictResolutionStatus.adoptRemoteRequested) {
            applicable.add(change);
            adopted[change.recordId] = refreshed;
          } else {
            conflicts.add(
              _HealthConflictCandidate(change: change, local: localForConflict),
            );
          }
          continue;
        }

        if (local != null && local.syncStatus != 'synced') {
          if (local.syncStatus == 'local_only' &&
              !_hasMetrics(local) &&
              local.serverVersion == null &&
              local.deletedAt == null) {
            applicable.add(change);
            continue;
          }
          conflicts.add(_HealthConflictCandidate(change: change, local: local));
          continue;
        }
        if (payload is HealthSyncPayload) {
          final dateOwner = activeByDate[payload.recordDate];
          if (dateOwner != null && dateOwner.id != change.recordId) {
            if (dateOwner.syncStatus == 'local_only' &&
                !_hasMetrics(dateOwner) &&
                dateOwner.serverVersion == null) {
              await (_database.update(_database.healthRecords)..where(
                    (row) =>
                        row.userId.equals(context.userId) &
                        row.id.equals(dateOwner.id),
                  ))
                  .write(
                    db.HealthRecordsCompanion(
                      todayRecordId: const Value(null),
                      updatedAt: Value(syncedAt),
                      deletedAt: Value(syncedAt),
                      syncStatus: const Value('synced'),
                    ),
                  );
              byId.remove(dateOwner.id);
              activeByDate.remove(payload.recordDate);
            } else {
              conflicts.add(
                _HealthConflictCandidate(change: change, local: dateOwner),
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
            scope: scope,
            candidate: candidate,
            detectedAt: syncedAt,
          );
          await (_database.update(_database.healthRecords)..where(
                (row) =>
                    row.userId.equals(context.userId) &
                    row.id.equals(candidate.local.id),
              ))
              .write(
                const db.HealthRecordsCompanion(syncStatus: Value('conflict')),
              );
        }
        return SyncEntityResult(
          entityType: entityType,
          status: SyncEntityStatus.conflict,
          message: '检测到 ${conflicts.length} 个 Health 冲突，本地内容未被覆盖',
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
        adopted: adopted,
      );
      applicable.sort(
        (left, right) => left.serverVersion.compareTo(right.serverVersion),
      );
      var applied = 0;
      var deleted = 0;
      for (final change in applicable) {
        final conflict = adopted[change.recordId];
        if (conflict != null && conflict.recordId != change.recordId) {
          await _applyAdoptRemoteDifferentIdentity(
            context: context,
            conflict: conflict,
            change: change,
            syncedAt: syncedAt,
          );
          await _conflictRepository!.markResolvedAdoptRemote(
            scope!,
            conflict.id,
            resolvedAt: syncedAt,
          );
          applied += 1;
          if (change.operation == SyncOperation.delete) deleted += 1;
          continue;
        }

        if (change.operation == SyncOperation.delete) {
          if (!byId.containsKey(change.recordId)) {
            ignored += 1;
            continue;
          }
          await (_database.update(_database.healthRecords)..where(
                (row) =>
                    row.userId.equals(context.userId) &
                    row.id.equals(change.recordId),
              ))
              .write(
                db.HealthRecordsCompanion(
                  updatedAt: Value(change.updatedAt),
                  deletedAt: Value(change.deletedAt),
                  syncStatus: const Value('synced'),
                  serverVersion: Value(change.serverVersion),
                  lastSyncedAt: Value(syncedAt),
                  originDeviceId: Value(change.originDeviceId),
                ),
              );
          if (conflict != null && scope != null) {
            await _conflictRepository!.markResolvedAdoptRemote(
              scope,
              conflict.id,
              resolvedAt: syncedAt,
            );
          }
          applied += 1;
          deleted += 1;
          continue;
        }

        final payload = change.payload;
        if (payload is! HealthSyncPayload) {
          throw const SyncException('云端 Health payload 类型无效。');
        }
        await _upsertRemote(
          context: context,
          change: change,
          payload: payload,
          syncedAt: syncedAt,
          exists: byId.containsKey(change.recordId),
        );
        if (conflict != null && scope != null) {
          await _conflictRepository!.markResolvedAdoptRemote(
            scope,
            conflict.id,
            resolvedAt: syncedAt,
          );
        }
        applied += 1;
      }

      return SyncEntityResult(
        entityType: entityType,
        status: applied == 0
            ? SyncEntityStatus.noChanges
            : SyncEntityStatus.succeeded,
        message: applied == 0 ? '没有新的 Health 更新' : 'Health 已更新',
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

  Future<void> _upsertRemote({
    required _HealthLocalContext context,
    required SyncChange change,
    required HealthSyncPayload payload,
    required int syncedAt,
    required bool exists,
  }) async {
    final todayRecordId = await _findTodayRecordId(
      userId: context.userId,
      recordDate: payload.recordDate,
    );
    if (!exists) {
      final global = await (_database.select(
        _database.healthRecords,
      )..where((row) => row.id.equals(change.recordId))).getSingleOrNull();
      if (global != null) {
        throw const SyncException('云端 Health ID 与其他本地用户冲突。');
      }
      await _database
          .into(_database.healthRecords)
          .insert(
            db.HealthRecordsCompanion.insert(
              id: Value(change.recordId),
              userId: context.userId,
              todayRecordId: Value(todayRecordId),
              recordDate: payload.recordDate,
              timezoneOffsetMinutes: payload.timezoneOffsetMinutes,
              sleepDurationMinutes: Value(payload.sleepDurationMinutes),
              weightKg: Value(payload.weightKg),
              waterIntakeMl: Value(payload.waterIntakeMl),
              exerciseType: Value(payload.exerciseType),
              exerciseDurationMinutes: Value(payload.exerciseDurationMinutes),
              physicalStateScore: Value(payload.physicalStateScore),
              note: Value(payload.note),
              dataSource: Value(payload.dataSource),
              sourceRecordId: Value(payload.sourceRecordId),
              createdAt: Value(payload.createdAt),
              updatedAt: Value(change.updatedAt),
              deletedAt: Value(change.deletedAt),
              syncStatus: const Value('synced'),
              serverVersion: Value(change.serverVersion),
              lastSyncedAt: Value(syncedAt),
              originDeviceId: Value(change.originDeviceId),
            ),
          );
      return;
    }
    await (_database.update(_database.healthRecords)..where(
          (row) =>
              row.userId.equals(context.userId) &
              row.id.equals(change.recordId),
        ))
        .write(
          db.HealthRecordsCompanion(
            todayRecordId: Value(todayRecordId),
            recordDate: Value(payload.recordDate),
            timezoneOffsetMinutes: Value(payload.timezoneOffsetMinutes),
            sleepDurationMinutes: Value(payload.sleepDurationMinutes),
            weightKg: Value(payload.weightKg),
            waterIntakeMl: Value(payload.waterIntakeMl),
            exerciseType: Value(payload.exerciseType),
            exerciseDurationMinutes: Value(payload.exerciseDurationMinutes),
            physicalStateScore: Value(payload.physicalStateScore),
            note: Value(payload.note),
            dataSource: Value(payload.dataSource),
            sourceRecordId: Value(payload.sourceRecordId),
            createdAt: Value(payload.createdAt),
            updatedAt: Value(change.updatedAt),
            deletedAt: Value(change.deletedAt),
            syncStatus: const Value('synced'),
            serverVersion: Value(change.serverVersion),
            lastSyncedAt: Value(syncedAt),
            originDeviceId: Value(change.originDeviceId),
          ),
        );
  }

  Future<void> _applyAdoptRemoteDifferentIdentity({
    required _HealthLocalContext context,
    required SyncConflictRecord conflict,
    required SyncChange change,
    required int syncedAt,
  }) async {
    final local = await _selectById(
      userId: context.userId,
      id: conflict.recordId,
    );
    if (local == null) throw const SyncConflictNotFoundException();
    final payload = change.payload;
    if (change.operation == SyncOperation.upsert &&
        payload is! HealthSyncPayload) {
      throw const SyncException('云端 Health payload 类型无效。');
    }
    await (_database.update(_database.healthRecords)..where(
          (row) =>
              row.userId.equals(context.userId) &
              row.id.equals(conflict.recordId),
        ))
        .write(
          db.HealthRecordsCompanion(
            todayRecordId: const Value(null),
            deletedAt: Value(local.deletedAt ?? syncedAt),
            syncStatus: const Value('synced'),
          ),
        );

    final remotePayload = payload is HealthSyncPayload ? payload : null;
    final global = await (_database.select(
      _database.healthRecords,
    )..where((row) => row.id.equals(change.recordId))).getSingleOrNull();
    if (global != null && global.userId != context.userId) {
      throw const SyncException('云端 Health ID 与其他本地用户冲突。');
    }
    await _upsertRemote(
      context: context,
      change: change,
      payload: remotePayload ?? _payloadFromRecord(local),
      syncedAt: syncedAt,
      exists: global != null,
    );
  }

  void _validateChange(SyncChange change, Set<String> seenIds) {
    if (change.entityType != entityType ||
        !HealthSyncPayloadCodec.isUuid(change.recordId) ||
        !HealthSyncPayloadCodec.isUuid(change.originDeviceId) ||
        !seenIds.add(change.recordId) ||
        change.updatedAt < 0 ||
        change.serverVersion < 0) {
      throw const SyncException('云端 Health 批次包含非法或重复记录。');
    }
    final validUpsert =
        change.operation == SyncOperation.upsert &&
        change.deletedAt == null &&
        change.payload is HealthSyncPayload;
    final validDelete =
        change.operation == SyncOperation.delete &&
        change.deletedAt != null &&
        change.deletedAt! >= 0 &&
        change.payload == null;
    if (!validUpsert && !validDelete) {
      throw const SyncException('云端 Health 操作字段不一致。');
    }
    if (change.payload case final HealthSyncPayload payload) {
      _payloadCodec.validate(payload);
    }
  }

  Future<void> _recordConflict({
    required SyncConflictScope? scope,
    required _HealthConflictCandidate candidate,
    required int detectedAt,
  }) async {
    if (scope == null || _conflictRepository == null) return;
    final existing = await _conflictRepository.findActiveConflict(
      scope: scope,
      entityType: entityType,
      recordId: candidate.local.id,
    );
    if (existing == null) {
      await _conflictRepository.upsertDetectedConflict(
        SyncConflictDetection(
          scope: scope,
          entityType: entityType,
          recordId: candidate.local.id,
          remoteRecordId: candidate.change.recordId,
          localSnapshot: _localSnapshot(candidate.local),
          remoteSnapshot: _remoteSnapshot(candidate.change),
          remoteOperation: candidate.change.operation == SyncOperation.delete
              ? SyncConflictOperation.delete
              : SyncConflictOperation.upsert,
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

  Future<SyncConflictRecord> _hydrateConflictIfNewer({
    required SyncConflictScope scope,
    required SyncConflictRecord active,
    required SyncChange change,
    required int seenAt,
  }) {
    if (_conflictRepository == null ||
        change.serverVersion < (active.remoteSnapshot.serverVersion ?? 0)) {
      return Future.value(active);
    }
    return _conflictRepository.hydrateRemoteSnapshot(
      scope: scope,
      entityType: entityType,
      recordId: active.recordId,
      remoteRecordId: change.recordId,
      operation: change.operation == SyncOperation.delete
          ? SyncConflictOperation.delete
          : SyncConflictOperation.upsert,
      remoteSnapshot: _remoteSnapshot(change),
      seenAt: seenAt,
    );
  }

  void _validateProjectedDates({
    required List<db.HealthRecord> current,
    required List<SyncChange> changes,
    required Map<String, SyncConflictRecord> adopted,
  }) {
    final dateById = {
      for (final row in current)
        if (row.deletedAt == null &&
            _hasMetrics(row) &&
            !adopted.values.any(
              (conflict) =>
                  conflict.recordId == row.id &&
                  conflict.remoteRecordId != row.id,
            ))
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
      final payload = change.payload! as HealthSyncPayload;
      final owner = ownerByDate[payload.recordDate];
      if (owner != null && owner != change.recordId) {
        throw const SyncException('云端 Health 自然日与本地记录冲突。');
      }
      dateById[change.recordId] = payload.recordDate;
      ownerByDate[payload.recordDate] = change.recordId;
    }
  }

  Future<_HealthLocalContext> _loadContext() async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    return _HealthLocalContext(
      userId: bootstrap.activeUserId,
      localInstallationId: bootstrap.localInstallationId,
    );
  }

  Future<SyncConflictScope?> _tryLoadConflictScope() {
    return _conflictScopeLoader?.call() ??
        Future<SyncConflictScope?>.value(null);
  }

  Future<db.HealthRecord?> _selectById({
    required String userId,
    required String id,
  }) {
    return (_database.select(_database.healthRecords)
          ..where((row) => row.userId.equals(userId) & row.id.equals(id)))
        .getSingleOrNull();
  }

  Future<String?> _findTodayRecordId({
    required String userId,
    required String recordDate,
  }) async {
    final today =
        await (_database.select(_database.todayRecords)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.recordDate.equals(recordDate) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    return today?.id;
  }

  HealthSyncPayload _payloadFromRecord(db.HealthRecord row) {
    return HealthSyncPayload(
      recordDate: row.recordDate,
      timezoneOffsetMinutes: row.timezoneOffsetMinutes,
      sleepDurationMinutes: row.sleepDurationMinutes,
      weightKg: row.weightKg,
      waterIntakeMl: row.waterIntakeMl,
      exerciseType: row.exerciseType,
      exerciseDurationMinutes: row.exerciseDurationMinutes,
      physicalStateScore: row.physicalStateScore,
      note: row.note,
      dataSource: row.dataSource,
      sourceRecordId: row.sourceRecordId,
      createdAt: row.createdAt,
    );
  }

  bool _hasMetrics(db.HealthRecord row) => _payloadFromRecord(row).hasMetrics;

  SyncConflictSnapshot _localSnapshot(db.HealthRecord row) {
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

final class _HealthLocalContext {
  const _HealthLocalContext({
    required this.userId,
    required this.localInstallationId,
  });

  final String userId;
  final String localInstallationId;
}

final class _HealthConflictCandidate {
  const _HealthConflictCandidate({required this.change, required this.local});

  final SyncChange change;
  final db.HealthRecord local;
}
