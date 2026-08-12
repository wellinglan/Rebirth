import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/ai_coach/data/local_ai_report_feedback_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback_repository.dart';

void main() {
  late AppDatabase database;
  late DateTime now;
  late LocalAiReportFeedbackRepository repository;
  late String userId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    now = DateTime.utc(2026, 8, 12, 1);
    repository = LocalAiReportFeedbackRepository(
      database: database,
      dateTimeService: DateTimeService(now: () => now),
    );
    userId = (await database.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    )).activeUserId;
    await _insertReport(database, userId: userId);
  });

  tearDown(() => database.close());

  test('reason codec is canonical and rejects unknown or duplicate values', () {
    const codec = AiReportFeedbackReasonCodec();
    expect(
      codec.encode(const [
        AiReportFeedbackReason.tooGeneric,
        AiReportFeedbackReason.notActionable,
        AiReportFeedbackReason.tooGeneric,
      ]),
      '["not_actionable","too_generic"]',
    );
    expect(codec.decode('["not_actionable","too_generic"]'), const [
      AiReportFeedbackReason.notActionable,
      AiReportFeedbackReason.tooGeneric,
    ]);
    expect(
      () => codec.decode('["too_generic","too_generic"]'),
      throwsFormatException,
    );
    expect(() => codec.decode('["custom_reason"]'), throwsFormatException);
  });

  test(
    'save is local-first, helpful is reason-free, and replay is idempotent',
    () async {
      final first = await repository.save(
        reportId: _reportId,
        reportVersion: 1,
        helpfulness: AiReportHelpfulness.helpful,
      );
      final replay = await repository.save(
        reportId: _reportId,
        reportVersion: 1,
        helpfulness: AiReportHelpfulness.helpful,
      );

      expect(first.syncStatus, AiReportFeedbackSyncStatus.pendingPush);
      expect(first.reasons, isEmpty);
      expect(replay.id, first.id);
      expect(replay.updatedAt, first.updatedAt);
      expect(
        await database.select(database.aiReportFeedback).get(),
        hasLength(1),
      );

      final changed = await repository.save(
        reportId: _reportId,
        reportVersion: 1,
        helpfulness: AiReportHelpfulness.notHelpful,
        reasons: const [
          AiReportFeedbackReason.tooGeneric,
          AiReportFeedbackReason.notActionable,
        ],
      );
      expect(changed.helpfulness, AiReportHelpfulness.notHelpful);
      expect(changed.reasons, const [
        AiReportFeedbackReason.notActionable,
        AiReportFeedbackReason.tooGeneric,
      ]);
    },
  );

  test(
    'database enforces one feedback per account and report version',
    () async {
      await repository.save(
        reportId: _reportId,
        reportVersion: 1,
        helpfulness: AiReportHelpfulness.helpful,
      );

      await expectLater(
        database
            .into(database.aiReportFeedback)
            .insert(
              AiReportFeedbackCompanion.insert(
                id: const Value('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
                userId: userId,
                reportId: _reportId,
                reportVersion: 1,
                reportType: 'weekly_report',
                helpfulness: 'helpful',
                promptId: 'weekly_report',
                promptVersion: 'weekly-report-v1',
                createdAt: const Value(1786496400000),
                updatedAt: const Value(1786496400000),
              ),
            ),
        throwsA(anything),
      );
    },
  );

  test(
    'not helpful requires a fixed reason and ineligible versions reject feedback',
    () async {
      await expectLater(
        repository.save(
          reportId: _reportId,
          reportVersion: 1,
          helpfulness: AiReportHelpfulness.notHelpful,
        ),
        throwsA(isA<AiReportFeedbackNotAllowedException>()),
      );
      await _insertReport(
        database,
        userId: userId,
        reportId: _failedReportId,
        versionId: _failedVersionId,
        reportStatus: 'failed',
        versionStatus: 'failed',
      );
      await expectLater(
        repository.save(
          reportId: _failedReportId,
          reportVersion: 1,
          helpfulness: AiReportHelpfulness.helpful,
        ),
        throwsA(isA<AiReportFeedbackNotAllowedException>()),
      );
    },
  );

  test('archived completed report remains eligible', () async {
    await (database.update(database.aiReports)
          ..where((row) => row.id.equals(_reportId)))
        .write(const AiReportsCompanion(reportStatus: Value('archived')));

    final feedback = await repository.save(
      reportId: _reportId,
      reportVersion: 1,
      helpfulness: AiReportHelpfulness.helpful,
    );

    expect(feedback.helpfulness, AiReportHelpfulness.helpful);
  });

  test('historical report versions keep independent feedback', () async {
    const timestamp = 1786496460000;
    await database
        .into(database.aiReportVersions)
        .insert(
          AiReportVersionsCompanion.insert(
            id: const Value('55555555-5555-4555-8555-555555555555'),
            reportId: _reportId,
            version: 2,
            status: 'completed',
            generationSource: 'manual',
            content: const Value('第二版报告正文'),
            sensitivity: 'high',
            quality: 'unreviewed',
            completedAt: const Value(timestamp),
            createdAt: const Value(timestamp),
            updatedAt: const Value(timestamp),
          ),
        );
    await (database.update(
      database.aiReports,
    )..where((row) => row.id.equals(_reportId))).write(
      const AiReportsCompanion(
        currentVersion: Value(2),
        reportContent: Value('第二版报告正文'),
        updatedAt: Value(timestamp),
      ),
    );

    await repository.save(
      reportId: _reportId,
      reportVersion: 1,
      helpfulness: AiReportHelpfulness.helpful,
    );
    await repository.save(
      reportId: _reportId,
      reportVersion: 2,
      helpfulness: AiReportHelpfulness.notHelpful,
      reasons: const [AiReportFeedbackReason.missedImportantContext],
    );

    expect(
      (await repository.getForVersion(
        reportId: _reportId,
        reportVersion: 1,
      ))?.helpfulness,
      AiReportHelpfulness.helpful,
    );
    expect(
      (await repository.getForVersion(
        reportId: _reportId,
        reportVersion: 2,
      ))?.reasons,
      [AiReportFeedbackReason.missedImportantContext],
    );
    expect(
      await database.select(database.aiReportFeedback).get(),
      hasLength(2),
    );
  });

  test(
    'clear removes never-synced feedback but tombstones synced feedback',
    () async {
      final local = await repository.save(
        reportId: _reportId,
        reportVersion: 1,
        helpfulness: AiReportHelpfulness.helpful,
      );
      await repository.clear(reportId: _reportId, reportVersion: 1);
      expect(await database.select(database.aiReportFeedback).get(), isEmpty);

      final synced = await repository.save(
        reportId: _reportId,
        reportVersion: 1,
        helpfulness: AiReportHelpfulness.helpful,
      );
      await repository.markSynced(
        id: synced.id,
        serverVersion: 1,
        serverUpdatedAt: now.millisecondsSinceEpoch,
      );
      now = now.add(const Duration(minutes: 1));
      await repository.clear(reportId: _reportId, reportVersion: 1);

      final row = await database.select(database.aiReportFeedback).getSingle();
      expect(row.id, local.id);
      expect(row.syncStatus, 'pending_delete');
      expect(row.deletedAt, now.millisecondsSinceEpoch);
      expect(
        await repository.getForVersion(reportId: _reportId, reportVersion: 1),
        isNull,
      );
    },
  );

  test(
    'remote conflict supports keep local and adopt remote without merging reasons',
    () async {
      final local = await repository.save(
        reportId: _reportId,
        reportVersion: 1,
        helpfulness: AiReportHelpfulness.helpful,
      );
      await repository.markSynced(
        id: local.id,
        serverVersion: 1,
        serverUpdatedAt: now.millisecondsSinceEpoch,
      );
      now = now.add(const Duration(minutes: 1));
      await repository.save(
        reportId: _reportId,
        reportVersion: 1,
        helpfulness: AiReportHelpfulness.notHelpful,
        reasons: const [AiReportFeedbackReason.tooGeneric],
      );
      final remote = AiReportFeedbackRemoteRecord(
        id: local.id,
        reportId: _reportId,
        reportVersion: 1,
        reportType: 'weekly_report',
        helpfulness: AiReportHelpfulness.helpful,
        reasons: const [],
        promptId: 'weekly_report',
        promptVersion: 'weekly-report-v1',
        serverVersion: 2,
        createdAt: now
            .subtract(const Duration(minutes: 2))
            .millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
        deletedAt: null,
      );
      await repository.applyRemote(remote);
      var conflicted = await repository.getForVersion(
        reportId: _reportId,
        reportVersion: 1,
      );
      expect(conflicted?.syncStatus, AiReportFeedbackSyncStatus.conflict);

      await repository.keepLocal(local.id);
      var kept = await repository.getForVersion(
        reportId: _reportId,
        reportVersion: 1,
      );
      expect(kept?.syncStatus, AiReportFeedbackSyncStatus.pendingPush);
      expect(kept?.serverVersion, 2);
      expect(kept?.helpfulness, AiReportHelpfulness.notHelpful);

      await repository.markConflict(id: local.id, remote: remote.snapshot);
      await repository.adoptRemote(local.id);
      final adopted = await repository.getForVersion(
        reportId: _reportId,
        reportVersion: 1,
      );
      expect(adopted?.syncStatus, AiReportFeedbackSyncStatus.synced);
      expect(adopted?.serverVersion, 2);
      expect(adopted?.helpfulness, AiReportHelpfulness.helpful);
      expect(adopted?.reasons, isEmpty);
    },
  );

  test('active account cannot read or rate another account report', () async {
    await repository.save(
      reportId: _reportId,
      reportVersion: 1,
      helpfulness: AiReportHelpfulness.helpful,
    );
    await (database.update(database.userProfiles)
          ..where((row) => row.id.equals(userId)))
        .write(const UserProfilesCompanion(isActive: Value(false)));
    const accountB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    final installation = await database
        .select(database.installationInfo)
        .getSingle();
    await database
        .into(database.userProfiles)
        .insert(
          UserProfilesCompanion.insert(
            id: const Value(accountB),
            timezoneId: 'Etc/UTC',
          ),
        );
    await database
        .into(database.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            userId: accountB,
            localInstallationId: installation.installationId,
          ),
        );

    expect(
      await repository.getForVersion(reportId: _reportId, reportVersion: 1),
      isNull,
    );
    await expectLater(
      repository.save(
        reportId: _reportId,
        reportVersion: 1,
        helpfulness: AiReportHelpfulness.helpful,
      ),
      throwsA(isA<AiReportFeedbackNotAllowedException>()),
    );
  });
}

const _reportId = '11111111-1111-4111-8111-111111111111';
const _versionId = '22222222-2222-4222-8222-222222222222';
const _failedReportId = '33333333-3333-4333-8333-333333333333';
const _failedVersionId = '44444444-4444-4444-8444-444444444444';

Future<void> _insertReport(
  AppDatabase database, {
  required String userId,
  String reportId = _reportId,
  String versionId = _versionId,
  String reportStatus = 'completed',
  String versionStatus = 'completed',
}) async {
  const timestamp = 1786496400000;
  final completed = versionStatus == 'completed';
  await database
      .into(database.aiReports)
      .insert(
        AiReportsCompanion.insert(
          id: Value(reportId),
          userId: userId,
          reportType: 'weekly_report',
          periodStartDate: '2026-08-03',
          periodEndDate: '2026-08-09',
          inputHash:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          promptVersion: 'weekly-report-v1',
          reportStatus: Value(reportStatus),
          reportContent: Value(completed ? '报告正文' : null),
          errorCode: Value(completed ? null : 'provider_failed'),
          currentVersion: const Value(1),
          requestedAt: timestamp,
          generatedAt: Value(completed ? timestamp : null),
          createdAt: const Value(timestamp),
          updatedAt: const Value(timestamp),
        ),
      );
  await database
      .into(database.aiReportVersions)
      .insert(
        AiReportVersionsCompanion.insert(
          id: Value(versionId),
          reportId: reportId,
          version: 1,
          status: versionStatus,
          generationSource: 'manual',
          content: Value(completed ? '报告正文' : null),
          sensitivity: 'high',
          quality: 'unreviewed',
          errorCode: Value(completed ? null : 'provider_failed'),
          completedAt: Value(completed ? timestamp : null),
          createdAt: const Value(timestamp),
          updatedAt: const Value(timestamp),
        ),
      );
}
