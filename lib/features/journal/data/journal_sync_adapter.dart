import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_sync_payload.dart';
import 'package:rebirth/features/sync/domain/sync_conflict.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_adapter.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

import 'journal_sync_payload_codec.dart';

final class JournalSyncAdapter implements SyncEntityAdapter {
  JournalSyncAdapter(
    this._database, [
    this._conflictRepository,
    this._conflictScopeLoader,
    this._payloadCodec = const JournalSyncPayloadCodec(),
  ]);

  final db.AppDatabase _database;
  final SyncConflictRepository? _conflictRepository;
  final Future<SyncConflictScope?> Function()? _conflictScopeLoader;
  final JournalSyncPayloadCodec _payloadCodec;

  @override
  SyncEntityType get entityType => SyncEntityType.journal;

  @override
  Future<List<SyncPushItem>> collectPending() async {
    final context = await _loadContext();
    final rows =
        await (_database.select(_database.journalEntries)..where(
              (row) =>
                  row.userId.equals(context.userId) &
                  row.syncStatus.isIn(const ['local_only', 'pending']),
            ))
            .get();
    rows.sort((left, right) {
      final date = left.entryDate.compareTo(right.entryDate);
      return date != 0 ? date : left.id.compareTo(right.id);
    });
    return rows
        .map((row) {
          final originDeviceId =
              row.originDeviceId ?? context.localInstallationId;
          if (!JournalSyncPayloadCodec.isUuid(row.id) ||
              !JournalSyncPayloadCodec.isUuid(originDeviceId)) {
            throw const SyncException('本地 Journal ID 或来源设备无效。');
          }
          if (row.deletedAt case final deletedAt? when deletedAt < 0) {
            throw const SyncException('本地 Journal tombstone 时间无效。');
          }
          final payload = row.deletedAt == null
              ? _payloadFromRecord(row)
              : null;
          if (payload != null) _payloadCodec.validate(payload);
          return SyncPushItem(
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
    if (!JournalSyncPayloadCodec.isUuid(recordId) ||
        !JournalSyncPayloadCodec.isUuid(originDeviceId) ||
        updatedAt < 0 ||
        serverVersion < 0 ||
        (deletedAt != null && deletedAt < 0)) {
      throw const SyncException('云端 Journal 同步元数据无效。');
    }
    final operation = deletedAt == null
        ? SyncOperation.upsert
        : SyncOperation.delete;
    if (operation == SyncOperation.delete && payload.isNotEmpty) {
      throw const SyncException('云端 Journal tombstone payload 必须为空。');
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
          throw const SyncException('Journal 上传上下文无效。');
        }
      }
      final responseIds = <String>{};
      for (final item in accepted) {
        if (item.entityType != entityType ||
            !submittedIds.contains(item.recordId) ||
            !responseIds.add(item.recordId)) {
          throw const SyncException('Journal 上传确认包含未提交或重复记录。');
        }
      }
      for (final item in conflicts) {
        if (item.tableName != entityType.wireName ||
            !submittedIds.contains(item.recordId) ||
            !responseIds.add(item.recordId)) {
          throw const SyncException('Journal 冲突响应包含未提交或重复记录。');
        }
      }
      if (responseIds.length != submittedIds.length) {
        throw const SyncException('Journal 上传响应不完整。');
      }

      final trueConflicts = conflicts
          .where((item) => item.reason != 'request_conflict')
          .toList(growable: false);
      final scope = accepted.isNotEmpty || trueConflicts.isNotEmpty
          ? await _tryLoadConflictScope()
          : null;

      for (final item in accepted) {
        final affected =
            await (_database.update(_database.journalEntries)..where(
                  (row) =>
                      row.userId.equals(context.userId) &
                      row.id.equals(item.recordId),
                ))
                .write(
                  db.JournalEntriesCompanion(
                    syncStatus: const Value('synced'),
                    serverVersion: Value(item.serverVersion),
                    lastSyncedAt: Value(syncedAt),
                  ),
                );
        if (affected != 1) {
          throw SyncException('找不到 Journal 上传记录 ${item.recordId}。');
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
          throw SyncException('找不到 Journal 冲突记录 ${item.recordId}。');
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
        await (_database.update(_database.journalEntries)..where(
              (row) =>
                  row.userId.equals(context.userId) & row.id.equals(local.id),
            ))
            .write(
              const db.JournalEntriesCompanion(syncStatus: Value('conflict')),
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
                  ? '没有需要上传的 Journal 更新'
                  : 'Journal 已上传'
            : 'Journal 上传存在版本冲突，本地内容已保留',
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
        _database.journalEntries,
      )..where((row) => row.userId.equals(context.userId))).get();
      final byId = {for (final row in current) row.id: row};
      final activeByDate = {
        for (final row in current)
          if (row.deletedAt == null) row.entryDate: row,
      };
      final applicable = <SyncChange>[];
      final conflicts = <_JournalConflictCandidate>[];
      final adopted = <String, SyncConflictRecord>{};
      final seenIds = <String>{};
      final seenDates = <String>{};
      final scope = changes.isEmpty ? null : await _tryLoadConflictScope();
      var ignored = 0;

      for (final change in changes) {
        _validateChange(change, seenIds);
        final payload = change.payload;
        if (payload is JournalSyncPayload &&
            !seenDates.add(payload.entryDate)) {
          throw const SyncException('云端 Journal 批次包含重复自然日。');
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
            throw const SyncException('Journal 冲突缺少本地记录。');
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
              _JournalConflictCandidate(
                change: change,
                local: localForConflict,
              ),
            );
          }
          continue;
        }

        if (local != null && local.syncStatus != 'synced') {
          conflicts.add(
            _JournalConflictCandidate(change: change, local: local),
          );
          continue;
        }
        if (payload is JournalSyncPayload) {
          final dateOwner = activeByDate[payload.entryDate];
          if (dateOwner != null && dateOwner.id != change.recordId) {
            conflicts.add(
              _JournalConflictCandidate(change: change, local: dateOwner),
            );
            continue;
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
          await (_database.update(_database.journalEntries)..where(
                (row) =>
                    row.userId.equals(context.userId) &
                    row.id.equals(candidate.local.id),
              ))
              .write(
                const db.JournalEntriesCompanion(syncStatus: Value('conflict')),
              );
        }
        return SyncEntityResult(
          entityType: entityType,
          status: SyncEntityStatus.conflict,
          message: '检测到 ${conflicts.length} 个 Journal 冲突，本地内容未被覆盖',
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
          await (_database.update(_database.journalEntries)..where(
                (row) =>
                    row.userId.equals(context.userId) &
                    row.id.equals(change.recordId),
              ))
              .write(
                db.JournalEntriesCompanion(
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
        if (payload is! JournalSyncPayload) {
          throw const SyncException('云端 Journal payload 类型无效。');
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
        message: applied == 0 ? '没有新的 Journal 更新' : 'Journal 已更新',
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
    required _JournalLocalContext context,
    required SyncChange change,
    required JournalSyncPayload payload,
    required int syncedAt,
    required bool exists,
  }) async {
    final todayRecordId = await _findTodayRecordId(
      userId: context.userId,
      entryDate: payload.entryDate,
    );
    if (!exists) {
      final global = await (_database.select(
        _database.journalEntries,
      )..where((row) => row.id.equals(change.recordId))).getSingleOrNull();
      if (global != null) {
        throw const SyncException('云端 Journal ID 与其他本地用户冲突。');
      }
      await _database
          .into(_database.journalEntries)
          .insert(
            db.JournalEntriesCompanion.insert(
              id: Value(change.recordId),
              userId: context.userId,
              todayRecordId: Value(todayRecordId),
              entryDate: payload.entryDate,
              timezoneOffsetMinutes: payload.timezoneOffsetMinutes,
              mostImportantAccomplishment: Value(
                payload.mostImportantAccomplishment,
              ),
              mostDrainingEvent: Value(payload.mostDrainingEvent),
              emotionSource: Value(payload.emotionSource),
              learning: Value(payload.learning),
              tomorrowAdjustment: Value(payload.tomorrowAdjustment),
              entryStatus: Value(payload.status.name),
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
    await (_database.update(_database.journalEntries)..where(
          (row) =>
              row.userId.equals(context.userId) &
              row.id.equals(change.recordId),
        ))
        .write(
          db.JournalEntriesCompanion(
            todayRecordId: Value(todayRecordId),
            entryDate: Value(payload.entryDate),
            timezoneOffsetMinutes: Value(payload.timezoneOffsetMinutes),
            mostImportantAccomplishment: Value(
              payload.mostImportantAccomplishment,
            ),
            mostDrainingEvent: Value(payload.mostDrainingEvent),
            emotionSource: Value(payload.emotionSource),
            learning: Value(payload.learning),
            tomorrowAdjustment: Value(payload.tomorrowAdjustment),
            entryStatus: Value(payload.status.name),
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
    required _JournalLocalContext context,
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
        payload is! JournalSyncPayload) {
      throw const SyncException('云端 Journal payload 类型无效。');
    }
    await (_database.update(_database.journalEntries)..where(
          (row) =>
              row.userId.equals(context.userId) &
              row.id.equals(conflict.recordId),
        ))
        .write(
          db.JournalEntriesCompanion(
            deletedAt: Value(local.deletedAt ?? syncedAt),
            syncStatus: const Value('synced'),
          ),
        );

    final remotePayload = payload is JournalSyncPayload ? payload : null;
    final global = await (_database.select(
      _database.journalEntries,
    )..where((row) => row.id.equals(change.recordId))).getSingleOrNull();
    if (global != null && global.userId != context.userId) {
      throw const SyncException('云端 Journal ID 与其他本地用户冲突。');
    }
    final resolvedPayload =
        remotePayload ??
        JournalSyncPayload(
          entryDate: local.entryDate,
          timezoneOffsetMinutes: local.timezoneOffsetMinutes,
          mostImportantAccomplishment: local.mostImportantAccomplishment,
          mostDrainingEvent: local.mostDrainingEvent,
          emotionSource: local.emotionSource,
          learning: local.learning,
          tomorrowAdjustment: local.tomorrowAdjustment,
          status: _status(local.entryStatus),
          createdAt: local.createdAt,
        );
    await _upsertRemote(
      context: context,
      change: change,
      payload: resolvedPayload,
      syncedAt: syncedAt,
      exists: global != null,
    );
  }

  void _validateChange(SyncChange change, Set<String> seenIds) {
    if (change.entityType != entityType ||
        !JournalSyncPayloadCodec.isUuid(change.recordId) ||
        !JournalSyncPayloadCodec.isUuid(change.originDeviceId) ||
        !seenIds.add(change.recordId) ||
        change.updatedAt < 0 ||
        change.serverVersion < 0) {
      throw const SyncException('云端 Journal 批次包含非法或重复记录。');
    }
    final validUpsert =
        change.operation == SyncOperation.upsert &&
        change.deletedAt == null &&
        change.payload is JournalSyncPayload;
    final validDelete =
        change.operation == SyncOperation.delete &&
        change.deletedAt != null &&
        change.deletedAt! >= 0 &&
        change.payload == null;
    if (!validUpsert && !validDelete) {
      throw const SyncException('云端 Journal 操作字段不一致。');
    }
    if (change.payload case final JournalSyncPayload payload) {
      _payloadCodec.validate(payload);
    }
  }

  Future<void> _recordConflict({
    required SyncConflictScope? scope,
    required _JournalConflictCandidate candidate,
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
    required List<db.JournalEntry> current,
    required List<SyncChange> changes,
    required Map<String, SyncConflictRecord> adopted,
  }) {
    final dateById = {
      for (final row in current)
        if (row.deletedAt == null &&
            !adopted.values.any(
              (conflict) =>
                  conflict.recordId == row.id &&
                  conflict.remoteRecordId != row.id,
            ))
          row.id: row.entryDate,
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
      final payload = change.payload! as JournalSyncPayload;
      final owner = ownerByDate[payload.entryDate];
      if (owner != null && owner != change.recordId) {
        throw const SyncException('云端 Journal 自然日与本地记录冲突。');
      }
      dateById[change.recordId] = payload.entryDate;
      ownerByDate[payload.entryDate] = change.recordId;
    }
  }

  Future<_JournalLocalContext> _loadContext() async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    return _JournalLocalContext(
      userId: bootstrap.activeUserId,
      localInstallationId: bootstrap.localInstallationId,
    );
  }

  Future<SyncConflictScope?> _tryLoadConflictScope() {
    return _conflictScopeLoader?.call() ??
        Future<SyncConflictScope?>.value(null);
  }

  Future<db.JournalEntry?> _selectById({
    required String userId,
    required String id,
  }) {
    return (_database.select(_database.journalEntries)
          ..where((row) => row.userId.equals(userId) & row.id.equals(id)))
        .getSingleOrNull();
  }

  Future<String?> _findTodayRecordId({
    required String userId,
    required String entryDate,
  }) async {
    final today =
        await (_database.select(_database.todayRecords)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.recordDate.equals(entryDate) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    return today?.id;
  }

  JournalSyncPayload _payloadFromRecord(db.JournalEntry row) {
    return JournalSyncPayload(
      entryDate: row.entryDate,
      timezoneOffsetMinutes: row.timezoneOffsetMinutes,
      mostImportantAccomplishment: row.mostImportantAccomplishment,
      mostDrainingEvent: row.mostDrainingEvent,
      emotionSource: row.emotionSource,
      learning: row.learning,
      tomorrowAdjustment: row.tomorrowAdjustment,
      status: _status(row.entryStatus),
      createdAt: row.createdAt,
    );
  }

  JournalEntryStatus _status(String value) => switch (value) {
    'draft' => JournalEntryStatus.draft,
    'completed' => JournalEntryStatus.completed,
    _ => throw const SyncException('Journal 状态无效。'),
  };

  SyncConflictSnapshot _localSnapshot(db.JournalEntry row) {
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

final class _JournalLocalContext {
  const _JournalLocalContext({
    required this.userId,
    required this.localInstallationId,
  });

  final String userId;
  final String localInstallationId;
}

final class _JournalConflictCandidate {
  const _JournalConflictCandidate({required this.change, required this.local});

  final SyncChange change;
  final db.JournalEntry local;
}
