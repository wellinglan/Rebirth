import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/ai_coach/data/canonical_json_encoder_impl.dart';
import 'package:rebirth/features/ai_coach/data/local_ai_report_repository.dart';
import 'package:rebirth/features/ai_coach/data/sha256_input_hash_service.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_exception.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_consent_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_authorization.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_selection.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_mode.dart';
import 'package:rebirth/features/ai_coach/domain/ai_input_source_ref.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';

void main() {
  late AppDatabase database;
  late DateTime currentTime;
  late _FakeConsentRepository consent;
  late List<String> ids;
  late LocalAiReportRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    currentTime = DateTime.utc(2026, 7, 16, 1);
    consent = _FakeConsentRepository(enabled: true);
    ids = [
      '11111111-1111-4111-8111-111111111111',
      '22222222-2222-4222-8222-222222222222',
      '33333333-3333-4333-8333-333333333333',
      '44444444-4444-4444-8444-444444444444',
      '55555555-5555-4555-8555-555555555555',
    ];
    repository = LocalAiReportRepository(
      database: database,
      dateTimeService: DateTimeService(now: () => currentTime),
      consentRepository: consent,
      canonicalJsonEncoder: const CanonicalJsonEncoderImpl(),
      idFactory: () => ids.removeAt(0),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'createPending stores a manual local-only report and stable sources',
    () async {
      final input = _bundle();
      final report = await repository.createPending(input: input);
      final raw = await database.select(database.aiReports).getSingle();

      expect(report.status, AiReportStatus.pending);
      expect(report.generationMode, AiGenerationMode.manual);
      expect(report.reportContent, isNull);
      expect(report.generatedAt, isNull);
      expect(raw.syncStatus, 'local_only');
      expect(raw.inputSnapshotJson, isNull);
      expect(
        raw.inputSourcesJson,
        '{"input_schema_version":1,"metadata_version":1,"scopes":["today_metrics"],"sources":[{"id":"source-a","table":"today_records","updated_at":10}]}',
      );
      expect(report.selectedScopes, {AiDataScope.todayMetrics});
      expect(report.inputMetadataVersion, 1);
      expect(report.inputSchemaVersion, 1);
      expect(raw.requestedAt, currentTime.millisecondsSinceEpoch);
    },
  );

  test('createPending rechecks consent before writing', () async {
    consent.authorization = const AiDataAuthorization.disabled();

    await expectLater(
      repository.createPending(input: _bundle()),
      throwsA(isA<AiConsentRequiredException>()),
    );
    expect(await database.select(database.aiReports).get(), isEmpty);
  });

  test('input snapshot is persisted only when explicitly selected', () async {
    final input = _bundle(persistInputSnapshot: true);
    await repository.createPending(input: input);
    final raw = await database.select(database.aiReports).getSingle();

    expect(raw.inputSnapshotJson, input.canonicalJson);
  });

  test('legacy source arrays remain readable without guessed scopes', () async {
    final pending = await repository.createPending(input: _bundle());
    await (database.update(
      database.aiReports,
    )..where((row) => row.id.equals(pending.id))).write(
      const AiReportsCompanion(
        inputSourcesJson: Value(
          '[{"id":"source-a","table":"today_records","updated_at":10}]',
        ),
      ),
    );

    final legacy = await repository.getById(pending.id);

    expect(legacy?.inputSources, hasLength(1));
    expect(legacy?.selectedScopes, isNull);
    expect(legacy?.inputMetadataVersion, isNull);
    expect(legacy?.inputSchemaVersion, isNull);
  });

  test(
    'daily pending and completed reuse use the single-day contract',
    () async {
      final input = _bundle(
        reportType: AiReportType.dailyInsight,
        periodStartDate: '2026-07-20',
        periodEndDate: '2026-07-20',
      );
      final pending = await repository.createPending(input: input);
      final raw = await database.select(database.aiReports).getSingle();
      expect(raw.reportType, 'daily_insight');
      expect(raw.promptVersion, 'daily-insight-v1');
      expect(raw.inputSnapshotJson, isNull);

      await repository.markCompleted(
        reportId: pending.id,
        reportContent: 'done',
      );
      final reusable = await repository.findReusableCompleted(
        reportType: AiReportType.dailyInsight,
        periodStartDate: '2026-07-20',
        periodEndDate: '2026-07-20',
        promptVersion: 'daily-insight-v1',
        inputHash: input.inputHash,
      );
      expect(reusable?.id, pending.id);
      expect(
        await repository.findReusableCompleted(
          reportType: AiReportType.weeklyReport,
          periodStartDate: '2026-07-20',
          periodEndDate: '2026-07-20',
          promptVersion: 'daily-insight-v1',
          inputHash: input.inputHash,
        ),
        isNull,
      );
    },
  );

  test(
    'markCompleted trims content and writes completion metadata atomically',
    () async {
      final pending = await repository.createPending(input: _bundle());
      currentTime = currentTime.add(const Duration(minutes: 5));

      final completed = await repository.markCompleted(
        reportId: pending.id,
        reportContent: '  local result  ',
        structuredOutputJson: ' {"kind":"weekly"} ',
        provider: ' future-provider ',
        model: ' future-model ',
      );

      expect(completed.status, AiReportStatus.completed);
      expect(completed.reportContent, 'local result');
      expect(completed.structuredOutputJson, '{"kind":"weekly"}');
      expect(completed.provider, 'future-provider');
      expect(completed.model, 'future-model');
      expect(completed.generatedAt, currentTime.millisecondsSinceEpoch);
      expect(completed.updatedAt, currentTime.millisecondsSinceEpoch);
    },
  );

  test(
    'empty completed content is rejected and leaves pending intact',
    () async {
      final pending = await repository.createPending(input: _bundle());

      await expectLater(
        repository.markCompleted(reportId: pending.id, reportContent: '  '),
        throwsA(isA<InvalidAiInputException>()),
      );
      expect(
        (await repository.getById(pending.id))!.status,
        AiReportStatus.pending,
      );
    },
  );

  test('markFailed stores only a controlled error classification', () async {
    final pending = await repository.createPending(input: _bundle());
    final failed = await repository.markFailed(
      reportId: pending.id,
      errorCode: 'request_failed',
    );

    expect(failed.status, AiReportStatus.failed);
    expect(failed.errorCode, 'request_failed');
    expect(failed.reportContent, isNull);
    expect(failed.generatedAt, isNull);
    await expectLater(
      repository.markFailed(
        reportId: ids.first,
        errorCode: 'HTTP 401 token=private',
      ),
      throwsA(isA<InvalidAiInputException>()),
    );
  });

  test('completed and failed reports cannot transition again', () async {
    final completedPending = await repository.createPending(input: _bundle());
    await repository.markCompleted(
      reportId: completedPending.id,
      reportContent: 'done',
    );
    await expectLater(
      repository.markFailed(
        reportId: completedPending.id,
        errorCode: 'unknown',
      ),
      throwsA(isA<InvalidAiReportTransitionException>()),
    );

    final failedPending = await repository.createPending(input: _bundle());
    await repository.markFailed(
      reportId: failedPending.id,
      errorCode: 'cancelled',
    );
    await expectLater(
      repository.markCompleted(
        reportId: failedPending.id,
        reportContent: 'not allowed',
      ),
      throwsA(isA<InvalidAiReportTransitionException>()),
    );
  });

  test(
    'reusable completed report matches all contract identity fields',
    () async {
      final input = _bundle();
      final pending = await repository.createPending(input: input);
      expect(
        await repository.findReusableCompleted(
          reportType: input.reportType,
          periodStartDate: input.periodStartDate,
          periodEndDate: input.periodEndDate,
          promptVersion: input.promptVersion,
          inputHash: input.inputHash,
        ),
        isNull,
      );
      await repository.markCompleted(
        reportId: pending.id,
        reportContent: 'done',
      );

      final reusable = await repository.findReusableCompleted(
        reportType: input.reportType,
        periodStartDate: input.periodStartDate,
        periodEndDate: input.periodEndDate,
        promptVersion: input.promptVersion,
        inputHash: input.inputHash,
      );
      expect(reusable?.id, pending.id);
      expect(
        await repository.findReusableCompleted(
          reportType: input.reportType,
          periodStartDate: input.periodStartDate,
          periodEndDate: input.periodEndDate,
          promptVersion: 'weekly-report-v2',
          inputHash: input.inputHash,
        ),
        isNull,
      );
      expect(
        await repository.findReusableCompleted(
          reportType: input.reportType,
          periodStartDate: input.periodStartDate,
          periodEndDate: input.periodEndDate,
          promptVersion: input.promptVersion,
          inputHash:
              'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        ),
        isNull,
      );
    },
  );

  test('failed report is not reusable', () async {
    final input = _bundle();
    final pending = await repository.createPending(input: input);
    await repository.markFailed(reportId: pending.id, errorCode: 'unknown');

    expect(
      await repository.findReusableCompleted(
        reportType: input.reportType,
        periodStartDate: input.periodStartDate,
        periodEndDate: input.periodEndDate,
        promptVersion: input.promptVersion,
        inputHash: input.inputHash,
      ),
      isNull,
    );
  });

  test(
    'listRecent sorts by request time and soft delete hides only report',
    () async {
      final first = await repository.createPending(input: _bundle());
      currentTime = currentTime.add(const Duration(minutes: 1));
      final second = await repository.createPending(input: _bundle());

      expect((await repository.listRecent()).map((report) => report.id), [
        second.id,
        first.id,
      ]);
      await repository.softDelete(second.id);
      expect(await repository.getById(second.id), isNull);
      expect((await repository.listRecent()).map((report) => report.id), [
        first.id,
      ]);
      expect(await database.select(database.todayRecords).get(), isEmpty);
      expect(await database.select(database.healthRecords).get(), isEmpty);
      expect(await database.select(database.journalEntries).get(), isEmpty);
    },
  );

  test(
    'revoked consent blocks new pending but does not alter existing report',
    () async {
      final existing = await repository.createPending(input: _bundle());
      consent.authorization = AiDataAuthorization(
        enabled: false,
        consentAt: consent.authorization.consentAt,
      );

      await expectLater(
        repository.createPending(input: _bundle()),
        throwsA(isA<AiConsentRequiredException>()),
      );
      expect(
        (await repository.getById(existing.id))?.status,
        AiReportStatus.pending,
      );
    },
  );
}

final class _FakeConsentRepository extends Fake implements AiConsentRepository {
  _FakeConsentRepository({required bool enabled})
    : authorization = enabled
          ? AiDataAuthorization(enabled: true, consentAt: 1)
          : const AiDataAuthorization.disabled();

  AiDataAuthorization authorization;

  @override
  Future<AiDataAuthorization> read() async => authorization;
}

AiCoachInputBundle _bundle({
  bool persistInputSnapshot = false,
  AiReportType reportType = AiReportType.weeklyReport,
  String periodStartDate = '2026-07-10',
  String periodEndDate = '2026-07-16',
}) {
  const encoder = CanonicalJsonEncoderImpl();
  const hashService = Sha256InputHashService();
  final selection = AiDataSelection(
    scopes: {AiDataScope.todayMetrics},
    persistInputSnapshot: persistInputSnapshot,
  );
  final source = AiInputSourceRef(
    table: 'today_records',
    id: 'source-a',
    updatedAt: 10,
  );
  final payload = <String, Object?>{
    'schema_version': 1,
    'report_type': reportType.databaseValue,
    'prompt_version': reportType == AiReportType.dailyInsight
        ? 'daily-insight-v1'
        : 'weekly-report-v1',
    'period': {'start_date': periodStartDate, 'end_date': periodEndDate},
    'scopes': ['today_metrics'],
    'data': {
      'today_metrics': [
        {'record_date': '2026-07-16', 'research_minutes': 0},
      ],
    },
    'sources': [source.toCanonicalMap()],
  };
  final canonicalJson = encoder.encode(payload);
  return AiCoachInputBundle(
    reportType: reportType,
    promptVersion: reportType == AiReportType.dailyInsight
        ? 'daily-insight-v1'
        : 'weekly-report-v1',
    periodStartDate: periodStartDate,
    periodEndDate: periodEndDate,
    selection: selection,
    sources: [source],
    canonicalPayload: payload,
    canonicalJson: canonicalJson,
    inputHash: hashService.hashCanonicalJson(canonicalJson),
  );
}
