import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/health/domain/health_entry.dart';
import 'package:rebirth/features/health/domain/health_summary.dart';

void main() {
  test('empty summary uses explicit null and zero semantics', () {
    final summary = HealthSummary.fromEntries(days: 7, entries: const []);

    expect(summary.recordsCount, 0);
    expect(summary.averageSleepMinutes, isNull);
    expect(summary.totalExerciseMinutes, isNull);
    expect(summary.averageWaterIntakeMl, isNull);
    expect(summary.latestWeightKg, isNull);
    expect(summary.latestPhysicalStateScore, isNull);
    expect(summary.hasData, isFalse);
  });

  test('calculates objective statistics from populated values', () {
    final summary = HealthSummary.fromEntries(
      days: 7,
      entries: [
        _entry(
          date: '2026-07-14',
          sleep: 480,
          exercise: 30,
          water: 2000,
          weight: 65.5,
          physicalState: 4,
        ),
        _entry(
          date: '2026-07-13',
          sleep: 420,
          exercise: null,
          water: 1000,
          weight: 66,
          physicalState: 3,
        ),
        _entry(date: '2026-07-12', exercise: 60),
      ],
    );

    expect(summary.recordsCount, 3);
    expect(summary.averageSleepMinutes, 450);
    expect(summary.totalExerciseMinutes, 90);
    expect(summary.averageWaterIntakeMl, 1500);
    expect(summary.latestWeightKg, 65.5);
    expect(summary.latestPhysicalStateScore, 4);
  });

  test('summary keeps an explicit zero duration', () {
    final summary = HealthSummary.fromEntries(
      days: 7,
      entries: [_entry(date: '2026-07-14', exercise: 0)],
    );

    expect(summary.totalExerciseMinutes, 0);
  });
}

HealthEntry _entry({
  required String date,
  int? sleep,
  int? exercise,
  int? water,
  double? weight,
  int? physicalState,
}) {
  return HealthEntry(
    id: date,
    userId: 'user',
    todayRecordId: null,
    recordDate: date,
    sleepDurationMinutes: sleep,
    weightKg: weight,
    waterIntakeMl: water,
    exerciseDurationMinutes: exercise,
    exerciseType: null,
    physicalStateScore: physicalState,
    note: null,
    timezoneOffsetMinutes: 480,
    createdAt: 1,
    updatedAt: 1,
  );
}
