import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/ai_coach/data/ai_report_conflict_resolution_service_impl.dart';
import 'package:rebirth/features/ai_coach/data/ai_report_sync_adapter.dart';
import 'package:rebirth/features/ai_coach/data/ai_report_sync_payload_codec.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_metadata.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_sync_payload.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';
import 'package:rebirth/features/sync/data/sync_conflict_repository_impl.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

void main() {
  late db.AppDatabase database;
  late SyncConflictRepositoryImpl conflicts;
  late AiReportSyncAdapter adapter;
  late AiReportConflictResolutionServiceImpl service;
  late SyncConflictScope scope;

  setUp(() async {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    final bootstrap = await database.bootstrapDao.bootstrap();
    scope = SyncConflictScope(
      localUserId: bootstrap.activeUserId,
      endpointKey: 'http://server-a:8000',
      cloudUserId: 'cloud-user-a',
    );
    conflicts = SyncConflictRepositoryImpl(
      database,
      payloadCodecs: const [AiReportSyncPayloadCodec()],
    );
    adapter = AiReportSyncAdapter(database, conflicts, () async => scope);
    service = AiReportConflictResolutionServiceImpl(
      database,
      conflicts,
      DateTimeService(now: _fixedNow),
    );
    await adapter.applyRemoteChanges(
      changes: [_change(_completedPayload, serverVersion: 4)],
      syncedAt: 100,
    );
    await (database.update(
      database.aiReports,
    )..where((row) => row.id.equals(_reportId))).write(
      const db.AiReportsCompanion(
        syncStatus: Value('conflict'),
        serverVersion: Value(4),
      ),
    );
  });

  tearDown(() => database.close());

  Future<SyncConflictRecord> createArchiveConflict() async {
    final local = await database.select(database.aiReports).getSingle();
    return conflicts.upsertDetectedConflict(
      SyncConflictDetection(
        scope: scope,
        entityType: SyncEntityType.aiReport,
        recordId: _reportId,
        remoteRecordId: _reportId,
        localSnapshot: SyncConflictSnapshot(
          payload: _completedPayload,
          updatedAt: local.updatedAt,
          deletedAt: null,
          serverVersion: local.serverVersion,
          originDeviceId: local.originDeviceId,
        ),
        remoteSnapshot: SyncConflictSnapshot(
          payload: _archivedPayload,
          updatedAt: 900,
          deletedAt: null,
          serverVersion: 6,
          originDeviceId: _remoteOriginId,
        ),
        remoteOperation: SyncConflictOperation.upsert,
        resolutionStatus: SyncConflictResolutionStatus.unresolved,
        detectedAt: 900,
      ),
    );
  }

  test(
    'Keep Local prepares a completed report for OCC retry without losing history',
    () async {
      final conflict = await createArchiveConflict();

      await service.requestKeepLocal(scope: scope, conflictId: conflict.id);

      final report = await database.select(database.aiReports).getSingle();
      final versions = await database.select(database.aiReportVersions).get();
      final requested = await conflicts.getConflict(scope, conflict.id);
      expect(report.reportStatus, 'completed');
      expect(report.reportContent, 'Safe report content');
      expect(report.serverVersion, 6);
      expect(report.syncStatus, 'pending');
      expect(versions, hasLength(1));
      expect(versions.single.content, 'Safe report content');
      expect(
        requested.resolutionStatus,
        SyncConflictResolutionStatus.keepLocalRequested,
      );
      expect(await adapter.collectPending(), hasLength(1));
    },
  );

  test(
    'Adopt Remote applies archive metadata and preserves immutable history',
    () async {
      final conflict = await createArchiveConflict();
      await service.requestAdoptRemote(scope: scope, conflictId: conflict.id);

      final result = await adapter.applyRemoteChanges(
        changes: [_change(_archivedPayload, serverVersion: 6)],
        syncedAt: 1000,
        pullMode: SyncPullMode.preferRemoteConflictResolution,
      );

      final report = await database.select(database.aiReports).getSingle();
      final versions = await database.select(database.aiReportVersions).get();
      final resolved = await conflicts.getConflict(scope, conflict.id);
      expect(result.status, SyncEntityStatus.succeeded);
      expect(report.reportStatus, 'archived');
      expect(report.reportContent, 'Safe report content');
      expect(report.serverVersion, 6);
      expect(report.syncStatus, 'synced');
      expect(versions, hasLength(1));
      expect(versions.single.content, 'Safe report content');
      expect(
        resolved.resolutionStatus,
        SyncConflictResolutionStatus.resolvedAdoptRemote,
      );
    },
  );
}

DateTime _fixedNow() => DateTime.utc(2026, 8, 4, 12);

const _reportId = '71111111-1111-4111-8111-111111111111';
const _versionId = '72222222-2222-4222-8222-222222222222';
const _remoteOriginId = '73333333-3333-4333-8333-333333333333';

final _completedPayload = AiReportSyncPayload(
  reportType: AiReportType.weeklyReport,
  title: 'Weekly review',
  periodStartDate: '2026-08-01',
  periodEndDate: '2026-08-07',
  status: AiReportStatus.completed,
  createdAt: 10,
  generationSource: 'ai_coach',
  sensitivity: AiReportSensitivity.high,
  quality: AiReportQuality.unreviewed,
  currentVersion: 1,
  versions: [
    AiReportVersionSyncPayload(
      id: _versionId,
      version: 1,
      status: AiReportStatus.completed,
      generationSource: 'ai_coach',
      content: 'Safe report content',
      sensitivity: AiReportSensitivity.high,
      quality: AiReportQuality.unreviewed,
      errorCode: null,
      createdAt: 10,
      completedAt: 11,
    ),
  ],
);

final _archivedPayload = AiReportSyncPayload(
  reportType: AiReportType.weeklyReport,
  title: 'Weekly review',
  periodStartDate: '2026-08-01',
  periodEndDate: '2026-08-07',
  status: AiReportStatus.archived,
  createdAt: 10,
  generationSource: 'ai_coach',
  sensitivity: AiReportSensitivity.high,
  quality: AiReportQuality.unreviewed,
  currentVersion: 1,
  versions: [
    AiReportVersionSyncPayload(
      id: _versionId,
      version: 1,
      status: AiReportStatus.completed,
      generationSource: 'ai_coach',
      content: 'Safe report content',
      sensitivity: AiReportSensitivity.high,
      quality: AiReportQuality.unreviewed,
      errorCode: null,
      createdAt: 10,
      completedAt: 11,
    ),
  ],
);

SyncChange _change(AiReportSyncPayload payload, {required int serverVersion}) =>
    SyncChange(
      entityType: SyncEntityType.aiReport,
      operation: SyncOperation.upsert,
      recordId: _reportId,
      payload: payload,
      updatedAt: serverVersion == 4 ? 20 : 900,
      deletedAt: null,
      originDeviceId: _remoteOriginId,
      serverVersion: serverVersion,
    );
