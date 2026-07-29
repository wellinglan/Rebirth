import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/features/journal/domain/journal_prompt.dart';
import 'package:rebirth/features/journal/domain/journal_prompt_repository.dart';
import 'package:rebirth/features/journal/domain/journal_prompt_sync_payload.dart';
import 'package:rebirth/features/sync/domain/sync_conflict.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_adapter.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

import 'journal_prompt_sync_payload_codec.dart';

final class JournalPromptSyncAdapter implements SyncEntityAdapter {
  JournalPromptSyncAdapter(
    this._database,
    this._promptRepository, [
    this._conflictRepository,
    this._conflictScopeLoader,
    this._codec = const JournalPromptSyncPayloadCodec(),
  ]);

  final db.AppDatabase _database;
  final JournalPromptRepository _promptRepository;
  final SyncConflictRepository? _conflictRepository;
  final Future<SyncConflictScope?> Function()? _conflictScopeLoader;
  final JournalPromptSyncPayloadCodec _codec;

  @override
  SyncEntityType get entityType => SyncEntityType.journalPromptConfiguration;

  @override
  Future<List<SyncPushItem>> collectPending() async {
    await _promptRepository.ensureInitialized();
    final context = await _context();
    final rows =
        await (_database.select(_database.journalPromptConfigurations)..where(
              (row) =>
                  row.userId.equals(context.userId) &
                  row.syncStatus.isIn(const ['local_only', 'pending']),
            ))
            .get();
    final items = <SyncPushItem>[];
    for (final row in rows) {
      final origin = row.originDeviceId ?? context.deviceId;
      if (!JournalPromptSyncPayloadCodec.isUuid(row.id) ||
          !JournalPromptSyncPayloadCodec.isUuid(origin)) {
        throw const SyncException('本地 Journal 问题配置同步元数据无效。');
      }
      final payload = row.deletedAt == null ? await _payload(row) : null;
      if (payload != null) _codec.validate(payload);
      items.add(
        SyncPushItem(
          entityType: entityType,
          operation: row.deletedAt == null
              ? SyncOperation.upsert
              : SyncOperation.delete,
          recordId: row.id,
          payload: payload,
          updatedAt: row.updatedAt,
          deletedAt: row.deletedAt,
          originDeviceId: origin,
          clientVersion: row.serverVersion ?? 0,
        ),
      );
    }
    return List.unmodifiable(items);
  }

  @override
  Map<String, Object?> encodePayload(SyncEntityPayload payload) {
    return _codec.encode(payload);
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
    if (!JournalPromptSyncPayloadCodec.isUuid(recordId) ||
        !JournalPromptSyncPayloadCodec.isUuid(originDeviceId) ||
        updatedAt < 0 ||
        serverVersion < 0 ||
        (deletedAt != null && deletedAt < 0)) {
      throw const SyncException('云端 Journal 问题配置同步元数据无效。');
    }
    final operation = deletedAt == null
        ? SyncOperation.upsert
        : SyncOperation.delete;
    if (operation == SyncOperation.delete && payload.isNotEmpty) {
      throw const SyncException('Journal 问题配置 tombstone payload 必须为空。');
    }
    return SyncChange(
      entityType: entityType,
      operation: operation,
      recordId: recordId,
      payload: operation == SyncOperation.upsert
          ? _codec.decode(recordId: recordId, json: payload)
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
      final context = await _context();
      final byId = {for (final item in submitted) item.recordId: item};
      if (byId.length != submitted.length ||
          submitted.any((item) => item.entityType != entityType)) {
        throw const SyncException('Journal 问题配置上传上下文无效。');
      }
      final responseIds = <String>{};
      for (final ack in accepted) {
        if (ack.entityType != entityType ||
            !byId.containsKey(ack.recordId) ||
            !responseIds.add(ack.recordId)) {
          throw const SyncException('Journal 问题配置上传确认无效。');
        }
      }
      for (final conflict in conflicts) {
        if (conflict.tableName != entityType.wireName ||
            !byId.containsKey(conflict.recordId) ||
            !responseIds.add(conflict.recordId)) {
          throw const SyncException('Journal 问题配置冲突响应无效。');
        }
      }
      if (responseIds.length != submitted.length) {
        throw const SyncException('Journal 问题配置上传响应不完整。');
      }

      final scope = accepted.isNotEmpty || conflicts.isNotEmpty
          ? await _scope()
          : null;
      for (final ack in accepted) {
        final submittedItem = byId[ack.recordId]!;
        final affected =
            await (_database.update(_database.journalPromptConfigurations)
                  ..where(
                    (row) =>
                        row.userId.equals(context.userId) &
                        row.id.equals(ack.recordId) &
                        row.updatedAt.equals(submittedItem.updatedAt),
                  ))
                .write(
                  db.JournalPromptConfigurationsCompanion(
                    syncStatus: const Value('synced'),
                    serverVersion: Value(ack.serverVersion),
                    lastSyncedAt: Value(syncedAt),
                  ),
                );
        if (affected == 0) {
          final stillExists = await _configuration(
            context.userId,
            ack.recordId,
          );
          if (stillExists == null) {
            throw const SyncException('Journal 问题配置上传记录不存在。');
          }
        }
        if (scope != null && _conflictRepository != null) {
          final conflict =
              await _conflictRepository.findActiveConflict(
                scope: scope,
                entityType: entityType,
                recordId: ack.recordId,
              ) ??
              await _conflictRepository.findActiveConflictByRemoteRecordId(
                scope: scope,
                entityType: entityType,
                remoteRecordId: ack.recordId,
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

      final actualConflicts = conflicts
          .where((item) => item.reason != 'request_conflict')
          .toList();
      for (final conflict in actualConflicts) {
        final local = await _configuration(context.userId, conflict.recordId);
        if (local == null) {
          throw const SyncException('Journal 问题配置冲突记录不存在。');
        }
        if (scope != null && _conflictRepository != null) {
          await _conflictRepository.upsertDetectedConflict(
            SyncConflictDetection(
              scope: scope,
              entityType: entityType,
              recordId: local.id,
              remoteRecordId: conflict.remoteRecordId ?? local.id,
              localSnapshot: await _snapshot(local),
              remoteSnapshot: SyncConflictSnapshot(
                payload: null,
                updatedAt: null,
                deletedAt: null,
                serverVersion: conflict.serverVersion,
                originDeviceId: null,
              ),
              remoteOperation: SyncConflictOperation.unknownPendingPull,
              resolutionStatus:
                  SyncConflictResolutionStatus.awaitingRemoteSnapshot,
              detectedAt: syncedAt,
            ),
          );
        }
        await (_database.update(_database.journalPromptConfigurations)..where(
              (row) =>
                  row.userId.equals(context.userId) & row.id.equals(local.id),
            ))
            .write(
              const db.JournalPromptConfigurationsCompanion(
                syncStatus: Value('conflict'),
              ),
            );
      }
      return SyncEntityResult(
        entityType: entityType,
        status: actualConflicts.isNotEmpty
            ? SyncEntityStatus.conflict
            : accepted.isEmpty
            ? SyncEntityStatus.noChanges
            : SyncEntityStatus.succeeded,
        message: actualConflicts.isNotEmpty
            ? 'Journal 问题配置存在版本冲突'
            : accepted.isEmpty
            ? '没有需要上传的问题配置'
            : 'Journal 问题配置已上传',
        pushedCount: accepted.length,
        conflictCount: actualConflicts.length,
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
      final context = await _context();
      final scope = changes.isEmpty ? null : await _scope();
      var applied = 0;
      var ignored = 0;
      var conflictCount = 0;
      final seen = <String>{};
      final ordered = changes.toList()
        ..sort(
          (left, right) => left.serverVersion.compareTo(right.serverVersion),
        );
      for (final change in ordered) {
        _validateChange(change, seen);
        var local = await _activeConfiguration(context.userId);
        if (local != null &&
            local.id == change.recordId &&
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
        activeConflict ??= scope == null || _conflictRepository == null
            ? null
            : await _conflictRepository.findActiveConflictByRemoteRecordId(
                scope: scope,
                entityType: entityType,
                remoteRecordId: change.recordId,
              );
        if (activeConflict != null) {
          final hydrated = await _hydrate(
            scope!,
            activeConflict,
            change,
            syncedAt,
          );
          final remotePayload = change.payload;
          if (local != null &&
              remotePayload is JournalPromptConfigurationSyncPayload &&
              _codec.semanticFingerprint(await _payload(local)) ==
                  _codec.semanticFingerprint(remotePayload)) {
            await _replaceWithRemote(
              context: context,
              local: local,
              change: change,
              payload: remotePayload,
              syncedAt: syncedAt,
            );
            await _conflictRepository!.markResolvedAdoptRemote(
              scope,
              hydrated.id,
              resolvedAt: syncedAt,
            );
            applied += 1;
            continue;
          }
          if (pullMode != SyncPullMode.preferRemoteConflictResolution ||
              hydrated.resolutionStatus !=
                  SyncConflictResolutionStatus.adoptRemoteRequested) {
            conflictCount += 1;
            continue;
          }
        }

        if (change.operation == SyncOperation.delete) {
          if (local == null) {
            ignored += 1;
            continue;
          }
          await (_database.update(_database.journalPromptConfigurations)..where(
                (row) =>
                    row.userId.equals(context.userId) & row.id.equals(local.id),
              ))
              .write(
                db.JournalPromptConfigurationsCompanion(
                  updatedAt: Value(change.updatedAt),
                  deletedAt: Value(change.deletedAt),
                  syncStatus: const Value('synced'),
                  serverVersion: Value(change.serverVersion),
                  lastSyncedAt: Value(syncedAt),
                  originDeviceId: Value(change.originDeviceId),
                ),
              );
          applied += 1;
          continue;
        }

        final payload = change.payload as JournalPromptConfigurationSyncPayload;
        final remoteFingerprint = _codec.semanticFingerprint(payload);
        final localPayload = local == null ? null : await _payload(local);
        final equivalent =
            localPayload != null &&
            _codec.semanticFingerprint(localPayload) == remoteFingerprint;
        final hasLocalChanges =
            local != null &&
            (local.syncStatus == 'local_only' ||
                local.syncStatus == 'pending' ||
                local.syncStatus == 'conflict');
        if (local != null &&
            activeConflict == null &&
            hasLocalChanges &&
            !equivalent) {
          await _recordConflict(
            scope: scope,
            local: local,
            change: change,
            detectedAt: syncedAt,
          );
          await (_database.update(
            _database.journalPromptConfigurations,
          )..where((row) => row.id.equals(local.id))).write(
            const db.JournalPromptConfigurationsCompanion(
              syncStatus: Value('conflict'),
            ),
          );
          conflictCount += 1;
          continue;
        }
        await _replaceWithRemote(
          context: context,
          local: local,
          change: change,
          payload: payload,
          syncedAt: syncedAt,
        );
        if (activeConflict != null && scope != null) {
          await _conflictRepository!.markResolvedAdoptRemote(
            scope,
            activeConflict.id,
            resolvedAt: syncedAt,
          );
        }
        applied += 1;
      }
      return SyncEntityResult(
        entityType: entityType,
        status: conflictCount > 0
            ? SyncEntityStatus.conflict
            : applied > 0
            ? SyncEntityStatus.succeeded
            : SyncEntityStatus.noChanges,
        message: conflictCount > 0
            ? 'Journal 问题配置存在冲突，本地配置已保留'
            : applied > 0
            ? 'Journal 问题配置已更新'
            : '没有新的 Journal 问题配置',
        pulledCount: applied,
        ignoredCount: ignored,
        conflictCount: conflictCount,
      );
    });
  }

  Future<void> _replaceWithRemote({
    required _PromptSyncContext context,
    required db.JournalPromptConfigurationRow? local,
    required SyncChange change,
    required JournalPromptConfigurationSyncPayload payload,
    required int syncedAt,
  }) async {
    final global = await (_database.select(
      _database.journalPromptConfigurations,
    )..where((row) => row.id.equals(change.recordId))).getSingleOrNull();
    if (global != null && global.userId != context.userId) {
      throw const SyncException('云端 Journal 问题配置属于其他本地账号。');
    }
    if (local != null && local.id != change.recordId) {
      await (_database.delete(
        _database.journalPromptDefinitions,
      )..where((row) => row.configurationId.equals(local.id))).go();
      await (_database.delete(_database.journalPromptConfigurations)..where(
            (row) =>
                row.userId.equals(context.userId) & row.id.equals(local.id),
          ))
          .go();
    }
    if (global == null) {
      await _database
          .into(_database.journalPromptConfigurations)
          .insert(
            db.JournalPromptConfigurationsCompanion.insert(
              id: Value(change.recordId),
              userId: context.userId,
              logicalKey: Value(payload.logicalKey),
              configurationVersion: Value(payload.configurationVersion),
              createdAt: Value(payload.createdAt),
              updatedAt: Value(change.updatedAt),
              syncStatus: const Value('synced'),
              serverVersion: Value(change.serverVersion),
              lastSyncedAt: Value(syncedAt),
              originDeviceId: Value(change.originDeviceId),
            ),
          );
    } else {
      await (_database.update(_database.journalPromptConfigurations)..where(
            (row) =>
                row.userId.equals(context.userId) &
                row.id.equals(change.recordId),
          ))
          .write(
            db.JournalPromptConfigurationsCompanion(
              configurationVersion: Value(payload.configurationVersion),
              createdAt: Value(payload.createdAt),
              updatedAt: Value(change.updatedAt),
              deletedAt: const Value(null),
              syncStatus: const Value('synced'),
              serverVersion: Value(change.serverVersion),
              lastSyncedAt: Value(syncedAt),
              originDeviceId: Value(change.originDeviceId),
            ),
          );
      await (_database.delete(
        _database.journalPromptDefinitions,
      )..where((row) => row.configurationId.equals(change.recordId))).go();
    }
    for (final prompt in payload.prompts) {
      await _insertPrompt(change.recordId, prompt);
    }
  }

  Future<void> _recordConflict({
    required SyncConflictScope? scope,
    required db.JournalPromptConfigurationRow local,
    required SyncChange change,
    required int detectedAt,
  }) async {
    if (scope == null || _conflictRepository == null) return;
    await _conflictRepository.upsertDetectedConflict(
      SyncConflictDetection(
        scope: scope,
        entityType: entityType,
        recordId: local.id,
        remoteRecordId: change.recordId,
        localSnapshot: await _snapshot(local),
        remoteSnapshot: _remoteSnapshot(change),
        remoteOperation: change.operation == SyncOperation.delete
            ? SyncConflictOperation.delete
            : SyncConflictOperation.upsert,
        resolutionStatus: SyncConflictResolutionStatus.unresolved,
        detectedAt: detectedAt,
      ),
    );
  }

  Future<SyncConflictRecord> _hydrate(
    SyncConflictScope scope,
    SyncConflictRecord active,
    SyncChange change,
    int syncedAt,
  ) {
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
      seenAt: syncedAt,
    );
  }

  void _validateChange(SyncChange change, Set<String> seen) {
    final upsert =
        change.operation == SyncOperation.upsert &&
        change.deletedAt == null &&
        change.payload is JournalPromptConfigurationSyncPayload;
    final deletion =
        change.operation == SyncOperation.delete &&
        change.deletedAt != null &&
        change.payload == null;
    if (change.entityType != entityType ||
        !seen.add(change.recordId) ||
        !JournalPromptSyncPayloadCodec.isUuid(change.recordId) ||
        !JournalPromptSyncPayloadCodec.isUuid(change.originDeviceId) ||
        change.updatedAt < 0 ||
        change.serverVersion < 0 ||
        (!upsert && !deletion)) {
      throw const SyncException('云端 Journal 问题配置变更无效。');
    }
    if (change.payload case final JournalPromptConfigurationSyncPayload p) {
      _codec.validate(p);
    }
  }

  Future<JournalPromptConfigurationSyncPayload> _payload(
    db.JournalPromptConfigurationRow row,
  ) async {
    final prompts =
        await (_database.select(_database.journalPromptDefinitions)
              ..where((item) => item.configurationId.equals(row.id))
              ..orderBy([
                (item) => OrderingTerm.asc(item.displayOrder),
                (item) => OrderingTerm.asc(item.id),
              ]))
            .get();
    return JournalPromptConfigurationSyncPayload(
      logicalKey: row.logicalKey,
      configurationVersion: row.configurationVersion,
      createdAt: row.createdAt,
      prompts: [for (final prompt in prompts) _domainPrompt(row.id, prompt)],
    );
  }

  JournalPromptDefinition _domainPrompt(
    String configurationId,
    db.JournalPromptDefinitionRow row,
  ) {
    return JournalPromptDefinition(
      id: row.id,
      configurationId: configurationId,
      stableKey: row.stableKey,
      source: JournalPromptSource.fromWireName(row.promptSource),
      questionText: row.questionText,
      helperText: row.helperText,
      responseKind: JournalResponseKind.fromWireName(row.responseKind),
      displayOrder: row.displayOrder,
      isEnabled: row.isEnabled,
      promptVersion: row.promptVersion,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  Future<void> _insertPrompt(
    String configurationId,
    JournalPromptDefinition prompt,
  ) {
    return _database
        .into(_database.journalPromptDefinitions)
        .insert(
          db.JournalPromptDefinitionsCompanion.insert(
            id: Value(prompt.id),
            configurationId: configurationId,
            stableKey: Value(prompt.stableKey),
            promptSource: prompt.source.wireName,
            questionText: prompt.questionText,
            helperText: Value(prompt.helperText),
            responseKind: Value(prompt.responseKind.wireName),
            displayOrder: prompt.displayOrder,
            isEnabled: Value(prompt.isEnabled),
            promptVersion: Value(prompt.promptVersion),
            createdAt: Value(prompt.createdAt),
            updatedAt: Value(prompt.updatedAt),
            deletedAt: Value(prompt.deletedAt),
          ),
        );
  }

  Future<SyncConflictSnapshot> _snapshot(
    db.JournalPromptConfigurationRow row,
  ) async {
    return SyncConflictSnapshot(
      payload: row.deletedAt == null ? await _payload(row) : null,
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

  Future<db.JournalPromptConfigurationRow?> _configuration(
    String userId,
    String id,
  ) {
    return (_database.select(_database.journalPromptConfigurations)
          ..where((row) => row.userId.equals(userId) & row.id.equals(id)))
        .getSingleOrNull();
  }

  Future<db.JournalPromptConfigurationRow?> _activeConfiguration(
    String userId,
  ) {
    return (_database.select(_database.journalPromptConfigurations)..where(
          (row) =>
              row.userId.equals(userId) &
              row.logicalKey.equals('default') &
              row.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  Future<_PromptSyncContext> _context() async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    return _PromptSyncContext(
      userId: bootstrap.activeUserId,
      deviceId: bootstrap.localInstallationId,
    );
  }

  Future<SyncConflictScope?> _scope() {
    return _conflictScopeLoader?.call() ??
        Future<SyncConflictScope?>.value(null);
  }
}

final class _PromptSyncContext {
  const _PromptSyncContext({required this.userId, required this.deviceId});

  final String userId;
  final String deviceId;
}
