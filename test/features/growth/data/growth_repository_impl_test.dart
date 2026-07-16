import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/growth/data/growth_repository_impl.dart';
import 'package:rebirth/features/growth/data/growth_repository_provider.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';
import 'package:rebirth/features/health/data/health_repository_provider.dart';
import 'package:rebirth/features/health/domain/health_entry.dart';
import 'package:rebirth/features/health/domain/health_repository.dart';
import 'package:rebirth/features/journal/data/journal_repository_provider.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_repository.dart';
import 'package:rebirth/features/today/data/today_repository_provider.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_repository.dart';

void main() {
  late _FakeTodayRepository todayRepository;
  late _FakeHealthRepository healthRepository;
  late _FakeJournalRepository journalRepository;
  late DateTimeService dateTimeService;
  late GrowthRepositoryImpl repository;

  setUp(() {
    todayRepository = _FakeTodayRepository();
    healthRepository = _FakeHealthRepository();
    journalRepository = _FakeJournalRepository();
    dateTimeService = DateTimeService(now: () => DateTime(2026, 7, 16, 9));
    repository = GrowthRepositoryImpl(
      todayRepository: todayRepository,
      healthRepository: healthRepository,
      journalRepository: journalRepository,
      dateTimeService: dateTimeService,
    );
  });

  test('7 day load includes today and queries every repository once', () async {
    final snapshot = await repository.loadRecent(GrowthPeriod.sevenDays);

    expect(snapshot.startDate, '2026-07-10');
    expect(snapshot.endDate, '2026-07-16');
    expect(snapshot.days, hasLength(7));
    _expectSingleRangeCall(
      todayRepository,
      healthRepository,
      journalRepository,
      startDate: '2026-07-10',
      endDate: '2026-07-16',
    );
  });

  test('30 day load includes today and returns ascending dates', () async {
    final snapshot = await repository.loadRecent(GrowthPeriod.thirtyDays);

    expect(snapshot.startDate, '2026-06-17');
    expect(snapshot.endDate, '2026-07-16');
    expect(snapshot.days, hasLength(30));
    expect(snapshot.days.first.date, '2026-06-17');
    expect(snapshot.days.last.date, '2026-07-16');
    _expectSingleRangeCall(
      todayRepository,
      healthRepository,
      journalRepository,
      startDate: '2026-06-17',
      endDate: '2026-07-16',
    );
  });

  test(
    'fixed local time handles cross-month, cross-year, and leap day',
    () async {
      final cases = <({DateTime now, String startDate, String endDate})>[
        (
          now: DateTime(2026, 3, 2, 9),
          startDate: '2026-02-24',
          endDate: '2026-03-02',
        ),
        (
          now: DateTime(2026, 1, 3, 9),
          startDate: '2025-12-28',
          endDate: '2026-01-03',
        ),
        (
          now: DateTime(2024, 3, 1, 9),
          startDate: '2024-02-24',
          endDate: '2024-03-01',
        ),
      ];

      for (final testCase in cases) {
        final localRepository = GrowthRepositoryImpl(
          todayRepository: _FakeTodayRepository(),
          healthRepository: _FakeHealthRepository(),
          journalRepository: _FakeJournalRepository(),
          dateTimeService: DateTimeService(now: () => testCase.now),
        );

        final snapshot = await localRepository.loadRecent(
          GrowthPeriod.sevenDays,
        );

        expect(snapshot.startDate, testCase.startDate);
        expect(snapshot.endDate, testCase.endDate);
      }
    },
  );

  test(
    'repository results are handed to the aggregator without zero fill',
    () async {
      todayRepository.entries = [
        _today(date: '2026-07-15', research: 0, learning: null, mood: 4),
      ];
      healthRepository.entries = [
        _health(date: '2026-07-15', sleep: 450, exercise: 30),
      ];
      journalRepository.entries = [
        _journal(date: '2026-07-15', status: JournalEntryStatus.draft),
      ];

      final snapshot = await repository.loadRecent(GrowthPeriod.sevenDays);
      final day = snapshot.days.singleWhere(
        (candidate) => candidate.date == '2026-07-15',
      );

      expect(day.researchMinutes, 0);
      expect(day.learningMinutes, isNull);
      expect(day.moodScore, 4);
      expect(day.sleepMinutes, 450);
      expect(day.exerciseMinutes, 30);
      expect(day.journalRecorded, isTrue);
      expect(day.journalCompleted, isFalse);
    },
  );

  test(
    'a lower repository exception is propagated without a partial snapshot',
    () async {
      final error = StateError('health range query failed');
      healthRepository.error = error;

      await expectLater(
        repository.loadRecent(GrowthPeriod.sevenDays),
        throwsA(same(error)),
      );
      expect(todayRepository.calls, 1);
      expect(healthRepository.calls, 1);
      expect(journalRepository.calls, 1);
    },
  );

  test(
    'provider composes the existing repository and time providers',
    () async {
      final container = ProviderContainer(
        overrides: [
          todayRepositoryProvider.overrideWithValue(todayRepository),
          healthRepositoryProvider.overrideWithValue(healthRepository),
          journalRepositoryProvider.overrideWithValue(journalRepository),
          dateTimeServiceProvider.overrideWithValue(dateTimeService),
        ],
      );
      addTearDown(container.dispose);

      final snapshot = await container
          .read(growthRepositoryProvider)
          .loadRecent(GrowthPeriod.sevenDays);

      expect(snapshot.endDate, '2026-07-16');
      expect(todayRepository.calls, 1);
      expect(healthRepository.calls, 1);
      expect(journalRepository.calls, 1);
    },
  );

  test(
    'Growth data layer has no Drift, AppDatabase, API, or page coupling',
    () {
      final implementation = File(
        'lib/features/growth/data/growth_repository_impl.dart',
      ).readAsStringSync();
      final page = File(
        'lib/features/growth/presentation/growth_page.dart',
      ).readAsStringSync();

      expect(implementation, isNot(contains('package:drift/')));
      expect(implementation, isNot(contains('AppDatabase')));
      expect(implementation, isNot(contains('ApiClient')));
      expect(implementation, isNot(contains('save')));
    expect(implementation, isNot(contains('features/sync/')));
      expect(page, isNot(contains('growthRepositoryProvider')));
    },
  );
}

void _expectSingleRangeCall(
  _FakeTodayRepository today,
  _FakeHealthRepository health,
  _FakeJournalRepository journal, {
  required String startDate,
  required String endDate,
}) {
  expect(today.calls, 1);
  expect(health.calls, 1);
  expect(journal.calls, 1);
  expect(today.startDate, startDate);
  expect(health.startDate, startDate);
  expect(journal.startDate, startDate);
  expect(today.endDate, endDate);
  expect(health.endDate, endDate);
  expect(journal.endDate, endDate);
}

final class _FakeTodayRepository implements TodayRepository {
  List<TodayEntry> entries = const [];
  Object? error;
  int calls = 0;
  String? startDate;
  String? endDate;

  @override
  Future<List<TodayEntry>> listByDateRange({
    required String startDate,
    required String endDate,
    int? limit,
  }) async {
    calls += 1;
    this.startDate = startDate;
    this.endDate = endDate;
    if (error != null) {
      throw error!;
    }
    return entries;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected TodayRepository call: $invocation');
  }
}

final class _FakeHealthRepository implements HealthRepository {
  List<HealthEntry> entries = const [];
  Object? error;
  int calls = 0;
  String? startDate;
  String? endDate;

  @override
  Future<List<HealthEntry>> listByDateRange({
    required String startDate,
    required String endDate,
  }) async {
    calls += 1;
    this.startDate = startDate;
    this.endDate = endDate;
    if (error != null) {
      throw error!;
    }
    return entries;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected HealthRepository call: $invocation');
  }
}

final class _FakeJournalRepository implements JournalRepository {
  List<JournalEntry> entries = const [];
  Object? error;
  int calls = 0;
  String? startDate;
  String? endDate;

  @override
  Future<List<JournalEntry>> listByDateRange({
    required String startDate,
    required String endDate,
    int? limit,
  }) async {
    calls += 1;
    this.startDate = startDate;
    this.endDate = endDate;
    if (error != null) {
      throw error!;
    }
    return entries;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected JournalRepository call: $invocation');
  }
}

TodayEntry _today({
  required String date,
  int? research,
  int? learning,
  int? mood,
}) {
  return TodayEntry(
    id: 'today-$date',
    userId: 'user',
    recordDate: date,
    timezoneOffsetMinutes: 480,
    priorities: const [TodayPriority(), TodayPriority(), TodayPriority()],
    moodScore: mood,
    energyScore: null,
    researchMinutes: research,
    learningMinutes: learning,
    dailyNote: null,
    status: TodayRecordStatus.draft,
    createdAt: 1,
    updatedAt: 1,
    health: null,
  );
}

HealthEntry _health({required String date, int? sleep, int? exercise}) {
  return HealthEntry(
    id: 'health-$date',
    userId: 'user',
    todayRecordId: null,
    recordDate: date,
    sleepDurationMinutes: sleep,
    weightKg: null,
    waterIntakeMl: null,
    exerciseDurationMinutes: exercise,
    exerciseType: null,
    physicalStateScore: null,
    note: null,
    timezoneOffsetMinutes: 480,
    createdAt: 1,
    updatedAt: 1,
  );
}

JournalEntry _journal({
  required String date,
  required JournalEntryStatus status,
}) {
  return JournalEntry(
    id: 'journal-$date',
    userId: 'user',
    todayRecordId: null,
    entryDate: date,
    timezoneOffsetMinutes: 480,
    mostImportantAccomplishment: '有内容',
    mostDrainingEvent: null,
    emotionSource: null,
    learning: null,
    tomorrowAdjustment: null,
    status: status,
    createdAt: 1,
    updatedAt: 1,
  );
}
