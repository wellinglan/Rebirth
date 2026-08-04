import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/features/ai_coach/domain/ai_report_metadata.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_sync_payload.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';
import 'package:rebirth/features/sync/domain/sync_conflict.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_adapter.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

import 'ai_report_sync_payload_codec.dart';

/// Syncs the Report aggregate. Versions travel as immutable children of one
/// report identity so Protocol v2 OCC can protect the whole artifact.
final class AiReportSyncAdapter implements SyncEntityAdapter {
  AiReportSyncAdapter(
    this._database, [
    this._conflictRepository,
    this._conflictScopeLoader,
    this._payloadCodec = const AiReportSyncPayloadCodec(),
  ]);

  final db.AppDatabase _database;
  final SyncConflictRepository? _conflictRepository;
  final Future<SyncConflictScope?> Function()? _conflictScopeLoader;
  final AiReportSyncPayloadCodec _payloadCodec;

  @override
  SyncEntityType get entityType => SyncEntityType.aiReport;

  @override
  Future<List<SyncPushItem>> collectPending() async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final rows =
        await (_database.select(_database.aiReports)..where(
              (row) =>
                  row.userId.equals(bootstrap.activeUserId) &
                  row.syncStatus.isIn(const ['local_only', 'pending']),
            ))
            .get();
    rows.sort((left, right) => left.id.compareTo(right.id));
    final items = <SyncPushItem>[];
    for (final row in rows) {
      if (!AiReportSyncPayloadCodec.isUuid(row.id)) {
        throw const SyncException('本地 AI 报告 ID 无效。');
      }
      final origin = row.originDeviceId ?? bootstrap.localInstallationId;
      if (!AiReportSyncPayloadCodec.isUuid(origin)) {
        throw const SyncException('本地 AI 报告来源设备无效。');
      }
      if (row.deletedAt != null) {
        items.add(
          SyncPushItem(
            entityType: entityType,
            operation: SyncOperation.delete,
            recordId: row.id,
            payload: null,
            updatedAt: row.updatedAt,
            deletedAt: row.deletedAt,
            originDeviceId: origin,
            clientVersion: row.serverVersion ?? 0,
          ),
        );
        continue;
      }
      if (!_isSyncableStatus(row.reportStatus)) continue;
      final payload = await _payloadFor(row);
      items.add(
        SyncPushItem(
          entityType: entityType,
          operation: SyncOperation.upsert,
          recordId: row.id,
          payload: payload,
          updatedAt: row.updatedAt,
          deletedAt: null,
          originDeviceId: origin,
          clientVersion: row.serverVersion ?? 0,
        ),
      );
    }
    return items;
  }

  @override
  Map<String, Object?> encodePayload(SyncEntityPayload payload) =>
      _payloadCodec.encode(payload);

  @override
  SyncChange decodeRemoteChange({
    required String recordId,
    required Map<String, Object?> payload,
    required int updatedAt,
    required int? deletedAt,
    required String originDeviceId,
    required int serverVersion,
  }) {
    if (!AiReportSyncPayloadCodec.isUuid(recordId) ||
        !AiReportSyncPayloadCodec.isUuid(originDeviceId) ||
        updatedAt < 0 ||
        serverVersion < 0 ||
        (deletedAt != null && deletedAt < 0)) {
      throw const SyncException('云端 AI 报告同步元数据无效。');
    }
    final operation = deletedAt == null
        ? SyncOperation.upsert
        : SyncOperation.delete;
    if (operation == SyncOperation.delete && payload.isNotEmpty) {
      throw const SyncException('云端 AI 报告 tombstone payload 必须为空。');
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
      final bootstrap = await _database.bootstrapDao.bootstrap();
      final submittedIds = {for (final item in submitted) item.recordId};
      if (submittedIds.length != submitted.length ||
          submitted.any((item) => item.entityType != entityType)) {
        throw const SyncException('AI 报告上传上下文无效。');
      }
      final responses = <String>{};
      for (final item in accepted) {
        if (item.entityType != entityType ||
            !submittedIds.contains(item.recordId) ||
            !responses.add(item.recordId)) {
          throw const SyncException('AI 报告上传确认无效。');
        }
      }
      for (final conflict in conflicts) {
        if (conflict.tableName != entityType.wireName ||
            !submittedIds.contains(conflict.recordId) ||
            !responses.add(conflict.recordId)) {
          throw const SyncException('AI 报告冲突响应无效。');
        }
      }
      if (responses.length != submittedIds.length) {
        throw const SyncException('AI 报告上传响应不完整。');
      }
      final trueConflicts = conflicts
          .where((item) => item.reason != 'request_conflict')
          .toList(growable: false);
      final scope = accepted.isNotEmpty || trueConflicts.isNotEmpty
          ? await _tryLoadConflictScope()
          : null;
      for (final item in accepted) {
        final affected =
            await (_database.update(_database.aiReports)..where(
                  (row) =>
                      row.userId.equals(bootstrap.activeUserId) &
                      row.id.equals(item.recordId),
                ))
                .write(
                  db.AiReportsCompanion(
                    syncStatus: const Value('synced'),
                    serverVersion: Value(item.serverVersion),
                    lastSyncedAt: Value(syncedAt),
                  ),
                );
        if (affected != 1) {
          throw SyncException('找不到 AI 报告上传记录 ${item.recordId}。');
        }
        if (scope != null && _conflictRepository != null) {
          final conflict = await _conflictRepository.findActiveConflict(
            scope: scope,
            entityType: entityType,
            recordId: item.recordId,
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
      for (final conflict in trueConflicts) {
        final local = await _selectById(
          bootstrap.activeUserId,
          conflict.recordId,
        );
        if (local == null) {
          throw SyncException('找不到 AI 报告冲突记录 ${conflict.recordId}。');
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
        await (_database.update(_database.aiReports)..where(
              (row) =>
                  row.userId.equals(bootstrap.activeUserId) &
                  row.id.equals(local.id),
            ))
            .write(const db.AiReportsCompanion(syncStatus: Value('conflict')));
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
                  ? '没有需要上传的 AI 报告更新'
                  : 'AI 报告已上传'
            : 'AI 报告上传存在版本冲突，本地内容已保留',
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
      final bootstrap = await _database.bootstrapDao.bootstrap();
      var pulled = 0;
      var deleted = 0;
      var conflicts = 0;
      for (final change in changes) {
        if (change.entityType != entityType) {
          throw const SyncException('AI 报告拉取实体类型无效。');
        }
        final local = await _selectById(
          bootstrap.activeUserId,
          change.recordId,
        );
        if (local != null && _requiresConflict(local, change, pullMode)) {
          await _recordRemoteConflict(
            local: local,
            change: change,
            syncedAt: syncedAt,
          );
          conflicts += 1;
          continue;
        }
        if (change.operation == SyncOperation.delete) {
          if (local != null) {
            await (_database.update(_database.aiReports)..where(
                  (row) =>
                      row.userId.equals(bootstrap.activeUserId) &
                      row.id.equals(local.id),
                ))
                .write(
                  db.AiReportsCompanion(
                    deletedAt: Value(change.deletedAt),
                    updatedAt: Value(change.updatedAt),
                    syncStatus: const Value('synced'),
                    serverVersion: Value(change.serverVersion),
                    lastSyncedAt: Value(syncedAt),
                    originDeviceId: Value(change.originDeviceId),
                  ),
                );
            deleted += 1;
          }
          await _resolveAdoptRemote(change.recordId, syncedAt);
          continue;
        }
        final payload = change.payload;
        if (payload is! AiReportSyncPayload) {
          throw const SyncException('云端 AI 报告 payload 无效。');
        }
        if (local == null) {
          await _insertRemoteReport(
            userId: bootstrap.activeUserId,
            change: change,
            payload: payload,
            syncedAt: syncedAt,
          );
        } else {
          final immutable = await _remoteVersionsAreCompatible(local, payload);
          if (!immutable) {
            await _recordRemoteConflict(
              local: local,
              change: change,
              syncedAt: syncedAt,
            );
            conflicts += 1;
            continue;
          }
          await _appendMissingVersions(local.id, payload.versions);
          final current = payload.versions.firstWhere(
            (version) => version.version == payload.currentVersion,
          );
          await (_database.update(_database.aiReports)..where(
                (row) =>
                    row.userId.equals(bootstrap.activeUserId) &
                    row.id.equals(local.id),
              ))
              .write(
                db.AiReportsCompanion(
                  reportType: Value(payload.reportType.databaseValue),
                  title: Value(payload.title),
                  periodStartDate: Value(payload.periodStartDate),
                  periodEndDate: Value(payload.periodEndDate),
                  reportStatus: Value(payload.status.databaseValue),
                  generationSource: Value(payload.generationSource),
                  sensitivity: Value(payload.sensitivity.databaseValue),
                  quality: Value(payload.quality.databaseValue),
                  currentVersion: Value(payload.currentVersion),
                  // A legacy projection only; immutable version rows remain source of truth.
                  reportContent: Value(current.content),
                  errorCode: Value(current.errorCode),
                  generatedAt: Value(current.completedAt),
                  updatedAt: Value(change.updatedAt),
                  deletedAt: const Value(null),
                  syncStatus: const Value('synced'),
                  serverVersion: Value(change.serverVersion),
                  lastSyncedAt: Value(syncedAt),
                  originDeviceId: Value(change.originDeviceId),
                ),
              );
        }
        await _resolveAdoptRemote(change.recordId, syncedAt);
        pulled += 1;
      }
      return SyncEntityResult(
        entityType: entityType,
        status: conflicts > 0
            ? SyncEntityStatus.conflict
            : pulled == 0 && deleted == 0
            ? SyncEntityStatus.noChanges
            : SyncEntityStatus.succeeded,
        message: conflicts > 0
            ? 'AI 报告存在冲突，本地版本已保留'
            : pulled == 0 && deleted == 0
            ? '没有新的 AI 报告更新'
            : 'AI 报告已同步',
        pulledCount: pulled,
        deletedCount: deleted,
        conflictCount: conflicts,
      );
    });
  }

  bool _requiresConflict(
    db.AiReport local,
    SyncChange remote,
    SyncPullMode pullMode,
  ) {
    if (pullMode == SyncPullMode.preferRemoteConflictResolution) return false;
    if (local.syncStatus == 'synced') return false;
    if (local.serverVersion == remote.serverVersion &&
        local.originDeviceId == remote.originDeviceId) {
      return false;
    }
    return local.deletedAt == null || remote.operation == SyncOperation.upsert;
  }

  bool _isSyncableStatus(String value) =>
      const {'completed', 'failed', 'archived'}.contains(value);

  Future<db.AiReport?> _selectById(String userId, String id) {
    return (_database.select(_database.aiReports)
          ..where((row) => row.userId.equals(userId) & row.id.equals(id)))
        .getSingleOrNull();
  }

  Future<AiReportSyncPayload> _payloadFor(db.AiReport report) async {
    final versions = await _versionsFor(report.id);
    final payload = AiReportSyncPayload(
      reportType: AiReportType.fromDatabaseValue(report.reportType),
      title: report.title,
      periodStartDate: report.periodStartDate,
      periodEndDate: report.periodEndDate,
      status: AiReportStatus.fromDatabaseValue(report.reportStatus),
      createdAt: report.createdAt,
      generationSource: report.generationSource,
      sensitivity: AiReportSensitivity.fromDatabaseValue(report.sensitivity),
      quality: AiReportQuality.fromDatabaseValue(report.quality),
      currentVersion: report.currentVersion,
      versions: versions,
    );
    _payloadCodec.validate(payload);
    return payload;
  }

  Future<List<AiReportVersionSyncPayload>> _versionsFor(String reportId) async {
    final rows =
        await (_database.select(_database.aiReportVersions)
              ..where((row) => row.reportId.equals(reportId))
              ..orderBy([(row) => OrderingTerm.asc(row.version)]))
            .get();
    return rows
        .map(
          (row) => AiReportVersionSyncPayload(
            id: row.id,
            version: row.version,
            status: AiReportStatus.fromDatabaseValue(row.status),
            generationSource: row.generationSource,
            content: row.content,
            sensitivity: AiReportSensitivity.fromDatabaseValue(row.sensitivity),
            quality: AiReportQuality.fromDatabaseValue(row.quality),
            errorCode: row.errorCode,
            createdAt: row.createdAt,
            completedAt: row.completedAt,
          ),
        )
        .toList(growable: false);
  }

  Future<SyncConflictSnapshot> _snapshot(db.AiReport row) async {
    return SyncConflictSnapshot(
      payload: row.deletedAt == null && _isSyncableStatus(row.reportStatus)
          ? await _payloadFor(row)
          : null,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      serverVersion: row.serverVersion,
      originDeviceId: row.originDeviceId,
    );
  }

  Future<void> _recordRemoteConflict({
    required db.AiReport local,
    required SyncChange change,
    required int syncedAt,
  }) async {
    final scope = await _tryLoadConflictScope();
    if (scope == null || _conflictRepository == null) {
      throw const SyncException('当前账号没有可用的 AI 报告冲突作用域。');
    }
    final remoteSnapshot = SyncConflictSnapshot(
      payload: change.payload,
      updatedAt: change.updatedAt,
      deletedAt: change.deletedAt,
      serverVersion: change.serverVersion,
      originDeviceId: change.originDeviceId,
    );
    final operation = change.operation == SyncOperation.delete
        ? SyncConflictOperation.delete
        : SyncConflictOperation.upsert;
    final existing = await _conflictRepository.findActiveConflict(
      scope: scope,
      entityType: entityType,
      recordId: local.id,
    );
    if (existing == null) {
      await _conflictRepository.upsertDetectedConflict(
        SyncConflictDetection(
          scope: scope,
          entityType: entityType,
          recordId: local.id,
          remoteRecordId: change.recordId,
          localSnapshot: await _snapshot(local),
          remoteSnapshot: remoteSnapshot,
          remoteOperation: operation,
          resolutionStatus: SyncConflictResolutionStatus.unresolved,
          detectedAt: syncedAt,
        ),
      );
    } else {
      await _conflictRepository.hydrateRemoteSnapshot(
        scope: scope,
        entityType: entityType,
        recordId: local.id,
        remoteRecordId: change.recordId,
        operation: operation,
        remoteSnapshot: remoteSnapshot,
        seenAt: syncedAt,
      );
    }
    await (_database.update(_database.aiReports)..where(
          (row) =>
              row.userId.equals(scope.localUserId) & row.id.equals(local.id),
        ))
        .write(const db.AiReportsCompanion(syncStatus: Value('conflict')));
  }

  Future<void> _insertRemoteReport({
    required String userId,
    required SyncChange change,
    required AiReportSyncPayload payload,
    required int syncedAt,
  }) async {
    final current = payload.versions.firstWhere(
      (version) => version.version == payload.currentVersion,
    );
    await _database
        .into(_database.aiReports)
        .insert(
          db.AiReportsCompanion.insert(
            id: Value(change.recordId),
            userId: userId,
            reportType: payload.reportType.databaseValue,
            title: Value(payload.title),
            periodStartDate: payload.periodStartDate,
            periodEndDate: payload.periodEndDate,
            inputHash: 'synced-${change.recordId}',
            promptVersion: 'synced-v2',
            reportStatus: Value(payload.status.databaseValue),
            generationSource: Value(payload.generationSource),
            sensitivity: Value(payload.sensitivity.databaseValue),
            quality: Value(payload.quality.databaseValue),
            currentVersion: Value(payload.currentVersion),
            reportContent: Value(current.content),
            errorCode: Value(current.errorCode),
            requestedAt: payload.createdAt,
            generatedAt: Value(current.completedAt),
            createdAt: Value(payload.createdAt),
            updatedAt: Value(change.updatedAt),
            syncStatus: const Value('synced'),
            serverVersion: Value(change.serverVersion),
            lastSyncedAt: Value(syncedAt),
            originDeviceId: Value(change.originDeviceId),
          ),
        );
    await _appendMissingVersions(change.recordId, payload.versions);
  }

  Future<bool> _remoteVersionsAreCompatible(
    db.AiReport report,
    AiReportSyncPayload remote,
  ) async {
    final existing = await _versionsFor(report.id);
    final remoteByNumber = {
      for (final item in remote.versions) item.version: item,
    };
    for (final local in existing) {
      final incoming = remoteByNumber[local.version];
      if (incoming == null ||
          incoming.id != local.id ||
          incoming.status != local.status ||
          incoming.generationSource != local.generationSource ||
          incoming.content != local.content ||
          incoming.sensitivity != local.sensitivity ||
          incoming.quality != local.quality ||
          incoming.errorCode != local.errorCode ||
          incoming.createdAt != local.createdAt ||
          incoming.completedAt != local.completedAt) {
        return false;
      }
    }
    return true;
  }

  Future<void> _appendMissingVersions(
    String reportId,
    List<AiReportVersionSyncPayload> remote,
  ) async {
    final existing = await (_database.select(
      _database.aiReportVersions,
    )..where((row) => row.reportId.equals(reportId))).get();
    final numbers = {for (final row in existing) row.version};
    for (final version in remote) {
      if (numbers.contains(version.version)) continue;
      await _database
          .into(_database.aiReportVersions)
          .insert(
            db.AiReportVersionsCompanion.insert(
              id: Value(version.id),
              reportId: reportId,
              version: version.version,
              status: version.status.databaseValue,
              generationSource: version.generationSource,
              modelMetadataJson: const Value(null),
              content: Value(version.content),
              sensitivity: version.sensitivity.databaseValue,
              quality: version.quality.databaseValue,
              errorCode: Value(version.errorCode),
              completedAt: Value(version.completedAt),
              createdAt: Value(version.createdAt),
              updatedAt: Value(version.createdAt),
            ),
          );
    }
  }

  Future<void> _resolveAdoptRemote(String reportId, int syncedAt) async {
    final scope = await _tryLoadConflictScope();
    if (scope == null || _conflictRepository == null) return;
    final conflict = await _conflictRepository.findActiveConflict(
      scope: scope,
      entityType: entityType,
      recordId: reportId,
    );
    if (conflict?.resolutionStatus ==
        SyncConflictResolutionStatus.adoptRemoteRequested) {
      await _conflictRepository.markResolvedAdoptRemote(
        scope,
        conflict!.id,
        resolvedAt: syncedAt,
      );
    }
  }

  Future<SyncConflictScope?> _tryLoadConflictScope() async {
    final loader = _conflictScopeLoader;
    return loader == null ? null : loader();
  }
}
