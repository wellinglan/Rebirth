import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_input_assembler_impl.dart';
import 'package:rebirth/features/ai_coach/data/canonical_json_encoder_impl.dart';
import 'package:rebirth/features/ai_coach/data/sha256_input_hash_service.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_exception.dart';
import 'package:rebirth/features/ai_coach/domain/ai_consent_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_authorization.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_selection.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';
import 'package:rebirth/features/growth/domain/growth_day_snapshot.dart';
import 'package:rebirth/features/growth/domain/growth_metric_summary.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';
import 'package:rebirth/features/growth/domain/growth_repository.dart';
import 'package:rebirth/features/growth/domain/growth_snapshot.dart';
import 'package:rebirth/features/health/domain/health_entry.dart';
import 'package:rebirth/features/health/domain/health_repository.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_repository.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_repository.dart';

void main() {
  late _FakeConsentRepository consent;
  late _FakeGrowthRepository growth;
  late _FakeTodayRepository today;
  late _FakeHealthRepository health;
  late _FakeJournalRepository journals;
  late AiCoachInputAssemblerImpl assembler;

  setUp(() {
    consent = _FakeConsentRepository(enabled: true);
    growth = _FakeGrowthRepository(_growthSnapshot());
    today = _FakeTodayRepository([
      _today(date: '2026-07-16', id: 'today-b', research: 0),
      _today(date: '2026-07-10', id: 'today-a', research: null),
    ]);
    health = _FakeHealthRepository([
      _health(date: '2026-07-16', id: 'health-b', sleep: 450),
      _health(date: '2026-07-10', id: 'health-a', sleep: null),
    ]);
    journals = _FakeJournalRepository([
      _journal(date: '2026-07-16', id: 'journal-b', learning: ' private '),
      _journal(date: '2026-07-10', id: 'journal-a', learning: '  '),
    ]);
    assembler = AiCoachInputAssemblerImpl(
      consentRepository: consent,
      growthRepository: growth,
      todayRepository: today,
      healthRepository: health,
      journalRepository: journals,
      dateTimeService: DateTimeService(now: () => DateTime(2026, 7, 16, 9)),
      canonicalJsonEncoder: const CanonicalJsonEncoderImpl(),
      inputHashService: const Sha256InputHashService(),
    );
  });

  test('consent off fails before any business repository query', () async {
    consent.authorization = const AiDataAuthorization.disabled();

    await expectLater(
      assembler.buildWeeklyReport(
        selection: AiDataSelection(scopes: {AiDataScope.todayMetrics}),
      ),
      throwsA(isA<AiConsentRequiredException>()),
    );

    expect(growth.calls, 0);
    expect(today.calls, 0);
    expect(health.calls, 0);
    expect(journals.calls, 0);
  });

  test('unsupported report type and active goals fail explicitly', () async {
    await expectLater(
      assembler.build(
        reportType: AiReportType.dailyInsight,
        selection: AiDataSelection(scopes: {AiDataScope.todayMetrics}),
      ),
      throwsA(isA<UnsupportedAiReportTypeException>()),
    );
    await expectLater(
      assembler.buildWeeklyReport(
        selection: AiDataSelection(scopes: {AiDataScope.activeGoals}),
      ),
      throwsA(isA<UnsupportedAiDataScopeException>()),
    );
    expect(today.calls, 0);
  });

  test('weekly bundle contains minimized selected data and stable period', () async {
    final bundle = await assembler.buildWeeklyReport(
      selection: AiDataSelection(
        scopes: {
          AiDataScope.journalReflections,
          AiDataScope.todayMetrics,
          AiDataScope.growthSummary,
          AiDataScope.healthMetrics,
        },
      ),
    );

    expect(bundle.periodStartDate, '2026-07-10');
    expect(bundle.periodEndDate, '2026-07-16');
    expect(bundle.promptVersion, 'weekly-report-v1');
    expect(bundle.canonicalPayload.keys, containsAll([
      'schema_version',
      'report_type',
      'prompt_version',
      'period',
      'scopes',
      'data',
      'sources',
    ]));
    expect(
      bundle.canonicalPayload['scopes'],
      [
        'growth_summary',
        'health_metrics',
        'journal_reflections',
        'today_metrics',
      ],
    );

    final data = bundle.canonicalPayload['data']! as Map<String, Object?>;
    final todayRows = data['today_metrics']! as List<Object?>;
    expect((todayRows.first! as Map<String, Object?>)['record_date'], '2026-07-10');
    expect((todayRows.first! as Map<String, Object?>)['research_minutes'], isNull);
    expect((todayRows.last! as Map<String, Object?>)['research_minutes'], 0);
    final todayJson = const CanonicalJsonEncoderImpl().encode(todayRows);
    expect(todayJson, isNot(contains('priority private text')));
    expect(todayJson, isNot(contains('daily private note')));
    expect(todayJson, isNot(contains('goal-private')));

    final healthRows = data['health_metrics']! as List<Object?>;
    final healthJson = const CanonicalJsonEncoderImpl().encode(healthRows);
    expect(healthJson, isNot(contains('health private note')));
    expect(healthJson, isNot(contains('source_record_id')));
    expect(healthJson, isNot(contains('today_record_id')));

    final journalRows = data['journal_reflections']! as List<Object?>;
    expect((journalRows.first! as Map<String, Object?>)['learning'], isNull);
    expect((journalRows.last! as Map<String, Object?>)['learning'], 'private');
    expect(bundle.canonicalJson, isNot(contains('local-user-private')));
    expect(bundle.canonicalJson, isNot(contains('device-private')));
    expect(bundle.canonicalJson, isNot(contains('access_token')));
    expect(bundle.canonicalJson, isNot(contains('endpoint')));
    expect(bundle.canonicalJson, isNot(contains('sync_status')));
    expect(bundle.inputHash, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(growth.calls, 1);
    expect(today.calls, 1);
    expect(health.calls, 1);
    expect(journals.calls, 1);
  });

  test('unselected Journal is neither queried nor represented', () async {
    final first = await assembler.buildWeeklyReport(
      selection: AiDataSelection(scopes: {AiDataScope.todayMetrics}),
    );
    journals.entries = [
      _journal(
        date: '2026-07-16',
        id: 'journal-b',
        learning: 'completely changed private content',
        updatedAt: 999,
      ),
    ];
    final second = await assembler.buildWeeklyReport(
      selection: AiDataSelection(scopes: {AiDataScope.todayMetrics}),
    );

    expect(journals.calls, 0);
    expect(first.inputHash, second.inputHash);
    expect(first.canonicalJson, isNot(contains('journal_reflections')));
    expect(first.sources.any((source) => source.table == 'journal_entries'), isFalse);
  });

  test('selected Journal content changes the input hash', () async {
    final selection = AiDataSelection(scopes: {AiDataScope.journalReflections});
    final first = await assembler.buildWeeklyReport(selection: selection);
    journals.entries = [
      _journal(
        date: '2026-07-16',
        id: 'journal-b',
        learning: 'changed reflection',
        updatedAt: 999,
      ),
    ];
    final second = await assembler.buildWeeklyReport(selection: selection);

    expect(first.inputHash, isNot(second.inputHash));
  });

  test('growth summary uses derived contract tracking without fake source table', () async {
    final bundle = await assembler.buildWeeklyReport(
      selection: AiDataSelection(scopes: {AiDataScope.growthSummary}),
    );
    final data = bundle.canonicalPayload['data']! as Map<String, Object?>;
    final summary = data['growth_summary']! as Map<String, Object?>;

    expect(summary['period_days'], 7);
    expect(summary['research'], isA<Map<String, Object?>>());
    expect(summary['journal_recorded_days'], 1);
    expect(bundle.sources, isEmpty);
    expect(bundle.canonicalJson, isNot(contains('growth_summary","id')));
    expect(growth.calls, 1);
    expect(today.calls, 0);
    expect(health.calls, 0);
    expect(journals.calls, 0);
  });

  test('source and scope input order are normalized before hashing', () async {
    final first = await assembler.buildWeeklyReport(
      selection: AiDataSelection(
        scopes: {AiDataScope.todayMetrics, AiDataScope.healthMetrics},
      ),
    );
    today.entries = today.entries.reversed.toList();
    health.entries = health.entries.reversed.toList();
    final second = await assembler.buildWeeklyReport(
      selection: AiDataSelection(
        scopes: {AiDataScope.healthMetrics, AiDataScope.todayMetrics},
      ),
    );

    expect(first.canonicalJson, second.canonicalJson);
    expect(first.inputHash, second.inputHash);
    expect(
      first.sources.map((source) => '${source.table}/${source.id}'),
      ['health_records/health-a', 'health_records/health-b', 'today_records/today-a', 'today_records/today-b'],
    );
  });

  test('duplicate source identity keeps one reference with latest updatedAt', () async {
    today.entries = [
      _today(date: '2026-07-10', id: 'same', research: 1, updatedAt: 10),
      _today(date: '2026-07-11', id: 'same', research: 2, updatedAt: 20),
    ];
    final bundle = await assembler.buildWeeklyReport(
      selection: AiDataSelection(scopes: {AiDataScope.todayMetrics}),
    );

    expect(bundle.sources, hasLength(1));
    expect(bundle.sources.single.updatedAt, 20);
  });

  test('repository failure is propagated without a partial bundle', () async {
    health.error = StateError('range read failed');

    await expectLater(
      assembler.buildWeeklyReport(
        selection: AiDataSelection(scopes: {AiDataScope.healthMetrics}),
      ),
      throwsA(isA<StateError>()),
    );
    expect(health.calls, 1);
  });
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

final class _FakeGrowthRepository extends Fake implements GrowthRepository {
  _FakeGrowthRepository(this.snapshot);

  GrowthSnapshot snapshot;
  int calls = 0;

  @override
  Future<GrowthSnapshot> loadRecent(GrowthPeriod period) async {
    calls += 1;
    return snapshot;
  }
}

final class _FakeTodayRepository extends Fake implements TodayRepository {
  _FakeTodayRepository(this.entries);

  List<TodayEntry> entries;
  int calls = 0;

  @override
  Future<List<TodayEntry>> listByDateRange({
    required String startDate,
    required String endDate,
    int? limit,
  }) async {
    calls += 1;
    return entries;
  }
}

final class _FakeHealthRepository extends Fake implements HealthRepository {
  _FakeHealthRepository(this.entries);

  List<HealthEntry> entries;
  Object? error;
  int calls = 0;

  @override
  Future<List<HealthEntry>> listByDateRange({
    required String startDate,
    required String endDate,
  }) async {
    calls += 1;
    if (error case final value?) throw value;
    return entries;
  }
}

final class _FakeJournalRepository extends Fake implements JournalRepository {
  _FakeJournalRepository(this.entries);

  List<JournalEntry> entries;
  int calls = 0;

  @override
  Future<List<JournalEntry>> listByDateRange({
    required String startDate,
    required String endDate,
    int? limit,
  }) async {
    calls += 1;
    return entries;
  }
}

GrowthSnapshot _growthSnapshot() {
  final days = List<GrowthDaySnapshot>.generate(7, (index) {
    final day = 10 + index;
    return GrowthDaySnapshot(
      date: '2026-07-${day.toString().padLeft(2, '0')}',
      researchMinutes: index == 0 ? null : index * 10,
      learningMinutes: index == 0 ? 0 : null,
      exerciseMinutes: null,
      sleepMinutes: null,
      moodScore: null,
      energyScore: null,
      journalRecorded: index == 6,
      journalCompleted: index == 6,
    );
  });
  return GrowthSnapshot(
    period: GrowthPeriod.sevenDays,
    startDate: days.first.date,
    endDate: days.last.date,
    days: days,
    researchSummary: GrowthMetricSummary.fromValues(
      days.map((day) => day.researchMinutes),
    ),
    learningSummary: GrowthMetricSummary.fromValues(
      days.map((day) => day.learningMinutes),
    ),
    exerciseSummary: GrowthMetricSummary.fromValues(
      days.map((day) => day.exerciseMinutes),
    ),
    sleepSummary: GrowthMetricSummary.fromValues(
      days.map((day) => day.sleepMinutes),
    ),
    moodSummary: GrowthMetricSummary.fromValues(
      days.map((day) => day.moodScore),
    ),
    energySummary: GrowthMetricSummary.fromValues(
      days.map((day) => day.energyScore),
    ),
    journalRecordedDays: 1,
    journalCompletedDays: 1,
  );
}

TodayEntry _today({
  required String date,
  required String id,
  required int? research,
  int updatedAt = 100,
}) {
  return TodayEntry(
    id: id,
    userId: 'local-user-private',
    recordDate: date,
    timezoneOffsetMinutes: 480,
    priorities: const [
      TodayPriority(
        text: 'priority private text',
        completed: true,
        goalId: 'goal-private',
      ),
      TodayPriority(),
      TodayPriority(),
    ],
    moodScore: 4,
    energyScore: null,
    researchMinutes: research,
    learningMinutes: 30,
    dailyNote: 'daily private note',
    status: TodayRecordStatus.draft,
    createdAt: 1,
    updatedAt: updatedAt,
    health: null,
  );
}

HealthEntry _health({
  required String date,
  required String id,
  required int? sleep,
}) {
  return HealthEntry(
    id: id,
    userId: 'local-user-private',
    todayRecordId: 'today-private',
    recordDate: date,
    sleepDurationMinutes: sleep,
    weightKg: 60.5,
    waterIntakeMl: 0,
    exerciseDurationMinutes: null,
    exerciseType: 'run',
    physicalStateScore: 5,
    note: 'health private note',
    timezoneOffsetMinutes: 480,
    createdAt: 1,
    updatedAt: 100,
  );
}

JournalEntry _journal({
  required String date,
  required String id,
  required String? learning,
  int updatedAt = 100,
}) {
  return JournalEntry(
    id: id,
    userId: 'local-user-private',
    todayRecordId: 'today-private',
    entryDate: date,
    timezoneOffsetMinutes: 480,
    mostImportantAccomplishment: ' accomplishment ',
    mostDrainingEvent: null,
    emotionSource: null,
    learning: learning,
    tomorrowAdjustment: null,
    status: JournalEntryStatus.completed,
    createdAt: 1,
    updatedAt: updatedAt,
  );
}
