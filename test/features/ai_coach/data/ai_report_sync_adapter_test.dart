import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/features/ai_coach/data/ai_report_sync_adapter.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_metadata.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_sync_payload.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

void main() {
  late AppDatabase database;
  late AiReportSyncAdapter adapter;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    adapter = AiReportSyncAdapter(database);
  });
  tearDown(() => database.close());

  test(
    'remote report aggregate appends immutable version then accepts tombstone',
    () async {
      final first = _change();
      final pulled = await adapter.applyRemoteChanges(
        changes: [first],
        syncedAt: 99,
      );
      final report = await database.select(database.aiReports).getSingle();
      final version = await database
          .select(database.aiReportVersions)
          .getSingle();
      expect(pulled.pulledCount, 1);
      expect(report.syncStatus, 'synced');
      expect(report.currentVersion, 1);
      expect(version.content, 'Safe report content');
      expect(version.modelMetadataJson, isNull);

      final deleted = await adapter.applyRemoteChanges(
        changes: [_change(operation: SyncOperation.delete, serverVersion: 2)],
        syncedAt: 100,
      );
      final deletedReport = await database
          .select(database.aiReports)
          .getSingle();
      expect(deleted.deletedCount, 1);
      expect(deletedReport.deletedAt, isNotNull);
      expect(
        await database.select(database.aiReportVersions).get(),
        hasLength(1),
      );
    },
  );
}

SyncChange _change({
  SyncOperation operation = SyncOperation.upsert,
  int serverVersion = 1,
}) => SyncChange(
  entityType: SyncEntityType.aiReport,
  operation: operation,
  recordId: '71111111-1111-4111-8111-111111111111',
  payload: operation == SyncOperation.upsert
      ? AiReportSyncPayload(
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
          versions: const [
            AiReportVersionSyncPayload(
              id: '72222222-2222-4222-8222-222222222222',
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
        )
      : null,
  updatedAt: 20,
  deletedAt: operation == SyncOperation.delete ? 21 : null,
  originDeviceId: '73333333-3333-4333-8333-333333333333',
  serverVersion: serverVersion,
);
