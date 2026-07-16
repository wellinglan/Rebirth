import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/growth/domain/growth_aggregator.dart';
import 'package:rebirth/features/growth/domain/growth_data_integrity_exception.dart';
import 'package:rebirth/features/growth/domain/growth_day_snapshot.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';
import 'package:rebirth/features/growth/domain/growth_snapshot.dart';
import 'package:rebirth/features/health/domain/health_entry.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';

void main() {
  const aggregator = GrowthAggregator();

  test('empty 7 day input still returns a complete null-valued skeleton', () {
    final snapshot = _aggregate(aggregator);

    expect(snapshot.days, hasLength(7));
    expect(snapshot.startDate, '2026-07-10');
    expect(snapshot.endDate, '2026-07-16');
    expect(snapshot.days.map((day) => day.date), orderedEquals(_dates(7)));
    for (final day in snapshot.days) {
      expect(day.researchMinutes, isNull);
      expect(day.learningMinutes, isNull);
      expect(day.exerciseMinutes, isNull);
      expect(day.sleepMinutes, isNull);
      expect(day.moodScore, isNull);
      expect(day.energyScore, isNull);
      expect(day.journalRecorded, isFalse);
      expect(day.journalCompleted, isFalse);
    }
  });

  test('empty 30 day input still returns 30 ascending points', () {
    final snapshot = _aggregate(aggregator, period: GrowthPeriod.thirtyDays);

    expect(snapshot.days, hasLength(30));
    expect(snapshot.startDate, '2026-06-17');
    expect(snapshot.endDate, '2026-07-16');
    expect(snapshot.days.map((day) => day.date), orderedEquals(_dates(30)));
  });

  test(
    'Today metrics preserve explicit zero and do not source Health data',
    () {
      final snapshot = _aggregate(
        aggregator,
        todayEntries: [
          _today(
            date: '2026-07-14',
            research: 0,
            learning: null,
            mood: 4,
            energy: 2,
            health: const TodayHealthSummary(
              id: 'embedded-health',
              sleepDurationMinutes: 999,
              exerciseDurationMinutes: 999,
            ),
          ),
        ],
      );
      final day = _day(snapshot, '2026-07-14');

      expect(day.researchMinutes, 0);
      expect(day.learningMinutes, isNull);
      expect(day.moodScore, 4);
      expect(day.energyScore, 2);
      expect(day.sleepMinutes, isNull);
      expect(day.exerciseMinutes, isNull);
    },
  );

  test('Health metrics map independently when Today is missing', () {
    final snapshot = _aggregate(
      aggregator,
      healthEntries: [_health(date: '2026-07-13', sleep: 450, exercise: 30)],
    );
    final day = _day(snapshot, '2026-07-13');

    expect(day.sleepMinutes, 450);
    expect(day.exerciseMinutes, 30);
    expect(day.researchMinutes, isNull);
    expect(day.moodScore, isNull);
  });

  test('missing Health does not affect mapped Today metrics', () {
    final snapshot = _aggregate(
      aggregator,
      todayEntries: [_today(date: '2026-07-12', research: 90, learning: 30)],
    );
    final day = _day(snapshot, '2026-07-12');

    expect(day.researchMinutes, 90);
    expect(day.learningMinutes, 30);
    expect(day.sleepMinutes, isNull);
    expect(day.exerciseMinutes, isNull);
  });

  test('Journal recorded uses hasContent while completed remains separate', () {
    final snapshot = _aggregate(
      aggregator,
      journalEntries: [
        _journal(
          id: 'draft-content',
          date: '2026-07-12',
          content: true,
          status: JournalEntryStatus.draft,
        ),
        _journal(
          id: 'completed-content',
          date: '2026-07-13',
          content: true,
          status: JournalEntryStatus.completed,
        ),
        _journal(
          id: 'empty-completed',
          date: '2026-07-14',
          content: false,
          status: JournalEntryStatus.completed,
        ),
      ],
    );

    expect(_day(snapshot, '2026-07-12').journalRecorded, isTrue);
    expect(_day(snapshot, '2026-07-12').journalCompleted, isFalse);
    expect(_day(snapshot, '2026-07-13').journalRecorded, isTrue);
    expect(_day(snapshot, '2026-07-13').journalCompleted, isTrue);
    expect(_day(snapshot, '2026-07-14').journalRecorded, isFalse);
    expect(_day(snapshot, '2026-07-14').journalCompleted, isFalse);
    expect(snapshot.journalRecordedDays, 2);
    expect(snapshot.journalCompletedDays, 1);
  });

  test(
    'an empty and a populated Journal on one date use the populated one',
    () {
      final snapshot = _aggregate(
        aggregator,
        journalEntries: [
          _journal(id: 'empty', date: '2026-07-15', content: false),
          _journal(id: 'content', date: '2026-07-15', content: true),
        ],
      );

      expect(_day(snapshot, '2026-07-15').journalRecorded, isTrue);
    },
  );

  test(
    'summaries calculate totals and nullable averages without zero fill',
    () {
      final snapshot = _aggregate(
        aggregator,
        todayEntries: [
          _today(date: '2026-07-11', research: 0, mood: 3),
          _today(date: '2026-07-12', research: 60, mood: 5),
          _today(date: '2026-07-13', research: null, mood: null),
        ],
        healthEntries: [
          _health(date: '2026-07-11', sleep: 420, exercise: 0),
          _health(date: '2026-07-12', sleep: 480, exercise: 30),
        ],
      );

      expect(snapshot.researchSummary.recordedDayCount, 2);
      expect(snapshot.researchSummary.total, 60);
      expect(snapshot.researchSummary.average, 30);
      expect(snapshot.researchSummary.minimum, 0);
      expect(snapshot.researchSummary.maximum, 60);
      expect(snapshot.exerciseSummary.recordedDayCount, 2);
      expect(snapshot.exerciseSummary.average, 15);
      expect(snapshot.sleepSummary.minimum, 420);
      expect(snapshot.sleepSummary.maximum, 480);
      expect(snapshot.moodSummary.average, 4);
      expect(snapshot.energySummary.recordedDayCount, 0);
      expect(snapshot.energySummary.average, isNull);
    },
  );

  test('duplicate Today dates throw a diagnostic integrity error', () {
    expect(
      () => _aggregate(
        aggregator,
        todayEntries: [
          _today(date: '2026-07-15'),
          _today(date: '2026-07-15'),
        ],
      ),
      throwsA(isA<GrowthDataIntegrityException>()),
    );
  });

  test('duplicate Health dates throw a diagnostic integrity error', () {
    expect(
      () => _aggregate(
        aggregator,
        healthEntries: [
          _health(date: '2026-07-15'),
          _health(date: '2026-07-15'),
        ],
      ),
      throwsA(isA<GrowthDataIntegrityException>()),
    );
  });

  test(
    'duplicate Journals with content throw a diagnostic integrity error',
    () {
      expect(
        () => _aggregate(
          aggregator,
          journalEntries: [
            _journal(id: 'one', date: '2026-07-15', content: true),
            _journal(id: 'two', date: '2026-07-15', content: true),
          ],
        ),
        throwsA(isA<GrowthDataIntegrityException>()),
      );
    },
  );

  test('invalid source and skeleton dates throw integrity errors', () {
    expect(
      () => _aggregate(aggregator, todayEntries: [_today(date: '2026-02-30')]),
      throwsA(isA<GrowthDataIntegrityException>()),
    );

    final invalidRange = _dates(7)..[2] = '2026-02-30';
    expect(
      () => _aggregate(aggregator, dateRange: invalidRange),
      throwsA(isA<GrowthDataIntegrityException>()),
    );
  });

  test(
    'negative duration values throw integrity errors instead of clamping',
    () {
      expect(
        () => _aggregate(
          aggregator,
          todayEntries: [_today(date: '2026-07-15', research: -1)],
        ),
        throwsA(isA<GrowthDataIntegrityException>()),
      );
      expect(
        () => _aggregate(
          aggregator,
          healthEntries: [_health(date: '2026-07-15', exercise: -1)],
        ),
        throwsA(isA<GrowthDataIntegrityException>()),
      );
    },
  );

  test('scores outside 1 to 5 throw integrity errors', () {
    expect(
      () => _aggregate(
        aggregator,
        todayEntries: [_today(date: '2026-07-15', mood: 6)],
      ),
      throwsA(isA<GrowthDataIntegrityException>()),
    );
  });

  test('valid out-of-range records are ignored before metric validation', () {
    final snapshot = _aggregate(
      aggregator,
      todayEntries: [_today(date: '2026-07-09', research: -1, mood: 6)],
      healthEntries: [_health(date: '2026-07-17', sleep: -1)],
    );

    expect(snapshot.researchSummary.recordedDayCount, 0);
    expect(snapshot.sleepSummary.recordedDayCount, 0);
  });

  test('date skeleton length and ordering are validated', () {
    expect(
      () => _aggregate(aggregator, dateRange: _dates(6)),
      throwsA(isA<GrowthDataIntegrityException>()),
    );
    final descending = _dates(7).reversed.toList();
    expect(
      () => _aggregate(aggregator, dateRange: descending),
      throwsA(isA<GrowthDataIntegrityException>()),
    );
  });
}

GrowthSnapshot _aggregate(
  GrowthAggregator aggregator, {
  GrowthPeriod period = GrowthPeriod.sevenDays,
  List<String>? dateRange,
  List<TodayEntry> todayEntries = const [],
  List<HealthEntry> healthEntries = const [],
  List<JournalEntry> journalEntries = const [],
}) {
  return aggregator.aggregate(
    period: period,
    dateRange: dateRange ?? _dates(period.days),
    todayEntries: todayEntries,
    healthEntries: healthEntries,
    journalEntries: journalEntries,
  );
}

List<String> _dates(int days) {
  return const DateTimeService().recentLocalDateRange(
    days,
    endingAt: DateTime(2026, 7, 16, 12),
  );
}

GrowthDaySnapshot _day(GrowthSnapshot snapshot, String date) {
  return snapshot.days.singleWhere((day) => day.date == date);
}

TodayEntry _today({
  required String date,
  int? research,
  int? learning,
  int? mood,
  int? energy,
  TodayHealthSummary? health,
}) {
  return TodayEntry(
    id: 'today-$date-${research ?? 'null'}',
    userId: 'user',
    recordDate: date,
    timezoneOffsetMinutes: 480,
    priorities: const [TodayPriority(), TodayPriority(), TodayPriority()],
    moodScore: mood,
    energyScore: energy,
    researchMinutes: research,
    learningMinutes: learning,
    dailyNote: null,
    status: TodayRecordStatus.draft,
    createdAt: 1,
    updatedAt: 1,
    health: health,
  );
}

HealthEntry _health({required String date, int? sleep, int? exercise}) {
  return HealthEntry(
    id: 'health-$date-${sleep ?? 'null'}',
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
  required String id,
  required String date,
  required bool content,
  JournalEntryStatus status = JournalEntryStatus.draft,
}) {
  return JournalEntry(
    id: id,
    userId: 'user',
    todayRecordId: null,
    entryDate: date,
    timezoneOffsetMinutes: 480,
    mostImportantAccomplishment: content ? '有实际内容' : null,
    mostDrainingEvent: null,
    emotionSource: null,
    learning: null,
    tomorrowAdjustment: null,
    status: status,
    createdAt: 1,
    updatedAt: 1,
  );
}
