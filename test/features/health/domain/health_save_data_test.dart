import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/health/domain/health_save_data.dart';

void main() {
  test('rejects invalid record date', () {
    expect(
      () => HealthSaveData(recordDate: '2026-02-30'),
      throwsA(isA<InvalidHealthDateException>()),
    );
  });

  test('rejects negative duration and water metrics', () {
    for (final create in <HealthSaveData Function()>[
      () => HealthSaveData(
        recordDate: '2026-07-14',
        sleepDurationMinutes: -1,
      ),
      () => HealthSaveData(
        recordDate: '2026-07-14',
        exerciseDurationMinutes: -1,
      ),
      () => HealthSaveData(recordDate: '2026-07-14', waterIntakeMl: -1),
    ]) {
      expect(create, throwsA(isA<InvalidHealthMetricException>()));
    }
  });

  test('rejects non-positive weight and out-of-range physical state', () {
    expect(
      () => HealthSaveData(recordDate: '2026-07-14', weightKg: 0),
      throwsA(isA<InvalidHealthMetricException>()),
    );
    expect(
      () => HealthSaveData(recordDate: '2026-07-14', weightKg: -0.1),
      throwsA(isA<InvalidHealthMetricException>()),
    );
    expect(
      () => HealthSaveData(recordDate: '2026-07-14', physicalStateScore: 6),
      throwsA(isA<InvalidHealthMetricException>()),
    );
  });

  test('normalizes blank text without truncating content', () {
    final longNote = '记录' * 500;
    final data = HealthSaveData(
      recordDate: '2026-07-14',
      exerciseType: '   ',
      note: '  $longNote  ',
    );

    expect(data.exerciseType, isNull);
    expect(data.note, longNote);
  });

  test('keeps null and zero distinct', () {
    final empty = HealthSaveData(recordDate: '2026-07-14');
    final zero = HealthSaveData(
      recordDate: '2026-07-14',
      sleepDurationMinutes: 0,
      exerciseDurationMinutes: 0,
      waterIntakeMl: 0,
    );

    expect(empty.sleepDurationMinutes, isNull);
    expect(zero.sleepDurationMinutes, 0);
    expect(zero.exerciseDurationMinutes, 0);
    expect(zero.waterIntakeMl, 0);
  });
}
