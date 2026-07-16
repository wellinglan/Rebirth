import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/growth/domain/growth_day_snapshot.dart';
import 'package:rebirth/features/growth/domain/growth_metric_summary.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';
import 'package:rebirth/features/growth/domain/growth_snapshot.dart';

void main() {
  test('GrowthPeriod exposes only the supported 7 and 30 day ranges', () {
    expect(GrowthPeriod.sevenDays.days, 7);
    expect(GrowthPeriod.thirtyDays.days, 30);
    expect(GrowthPeriod.values, hasLength(2));
  });

  test('summary excludes null and includes an explicit zero', () {
    final summary = GrowthMetricSummary.fromValues([null, 0, 30, 90]);

    expect(summary.recordedDayCount, 3);
    expect(summary.total, 120);
    expect(summary.average, 40);
    expect(summary.minimum, 0);
    expect(summary.maximum, 90);
  });

  test('summary keeps nullable statistics when every value is missing', () {
    final summary = GrowthMetricSummary.fromValues([null, null]);

    expect(summary.recordedDayCount, 0);
    expect(summary.total, 0);
    expect(summary.average, isNull);
    expect(summary.minimum, isNull);
    expect(summary.maximum, isNull);
  });

  test('GrowthSnapshot owns an unmodifiable ascending day list', () {
    final days = List<GrowthDaySnapshot>.generate(
      GrowthPeriod.sevenDays.days,
      (index) =>
          _emptyDay('2026-07-${(10 + index).toString().padLeft(2, '0')}'),
    );
    final emptySummary = GrowthMetricSummary.fromValues(const [null]);
    final snapshot = GrowthSnapshot(
      period: GrowthPeriod.sevenDays,
      startDate: '2026-07-10',
      endDate: '2026-07-16',
      days: days,
      researchSummary: emptySummary,
      learningSummary: emptySummary,
      exerciseSummary: emptySummary,
      sleepSummary: emptySummary,
      moodSummary: emptySummary,
      energySummary: emptySummary,
      journalRecordedDays: 0,
      journalCompletedDays: 0,
    );

    expect(snapshot.days, hasLength(7));
    expect(
      () => snapshot.days.add(_emptyDay('2026-07-17')),
      throwsUnsupportedError,
    );
  });
}

GrowthDaySnapshot _emptyDay(String date) {
  return GrowthDaySnapshot(
    date: date,
    researchMinutes: null,
    learningMinutes: null,
    exerciseMinutes: null,
    sleepMinutes: null,
    moodScore: null,
    energyScore: null,
    journalRecorded: false,
    journalCompleted: false,
  );
}
