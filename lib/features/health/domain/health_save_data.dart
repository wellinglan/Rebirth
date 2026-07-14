import 'package:rebirth/core/utils/date_time_service.dart';

final class InvalidHealthDateException implements Exception {
  const InvalidHealthDateException(this.recordDate);

  final String recordDate;

  @override
  String toString() => 'Invalid Health record date: $recordDate.';
}

final class InvalidHealthMetricException implements Exception {
  const InvalidHealthMetricException(this.metric, this.value);

  final String metric;
  final Object value;

  @override
  String toString() => 'Invalid Health metric $metric: $value.';
}

final class HealthSaveData {
  factory HealthSaveData({
    required String recordDate,
    int? sleepDurationMinutes,
    double? weightKg,
    int? waterIntakeMl,
    int? exerciseDurationMinutes,
    String? exerciseType,
    int? physicalStateScore,
    String? note,
  }) {
    const dateTimeService = DateTimeService();
    if (!dateTimeService.isValidLocalDateString(recordDate)) {
      throw InvalidHealthDateException(recordDate);
    }
    _validateNonNegative('sleepDurationMinutes', sleepDurationMinutes);
    _validateNonNegative('exerciseDurationMinutes', exerciseDurationMinutes);
    _validateNonNegative('waterIntakeMl', waterIntakeMl);
    if (weightKg != null && weightKg <= 0) {
      throw InvalidHealthMetricException('weightKg', weightKg);
    }
    if (physicalStateScore != null &&
        (physicalStateScore < 1 || physicalStateScore > 5)) {
      throw InvalidHealthMetricException(
        'physicalStateScore',
        physicalStateScore,
      );
    }

    return HealthSaveData._(
      recordDate: recordDate,
      sleepDurationMinutes: sleepDurationMinutes,
      weightKg: weightKg,
      waterIntakeMl: waterIntakeMl,
      exerciseDurationMinutes: exerciseDurationMinutes,
      exerciseType: _trimToNull(exerciseType),
      physicalStateScore: physicalStateScore,
      note: _trimToNull(note),
    );
  }

  const HealthSaveData._({
    required this.recordDate,
    required this.sleepDurationMinutes,
    required this.weightKg,
    required this.waterIntakeMl,
    required this.exerciseDurationMinutes,
    required this.exerciseType,
    required this.physicalStateScore,
    required this.note,
  });

  final String recordDate;
  final int? sleepDurationMinutes;
  final double? weightKg;
  final int? waterIntakeMl;
  final int? exerciseDurationMinutes;
  final String? exerciseType;
  final int? physicalStateScore;
  final String? note;

  static void _validateNonNegative(String name, int? value) {
    if (value != null && value < 0) {
      throw InvalidHealthMetricException(name, value);
    }
  }

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
