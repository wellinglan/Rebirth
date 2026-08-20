import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/metric_description.dart';

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
    String? sleepDescription,
    double? weightKg,
    String? weightDescription,
    int? waterIntakeMl,
    String? waterDescription,
    int? exerciseDurationMinutes,
    String? exerciseDescription,
    String? exerciseType,
    int? physicalStateScore,
    String? physicalStateDescription,
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
        (physicalStateScore < 1 || physicalStateScore > 10)) {
      throw InvalidHealthMetricException(
        'physicalStateScore',
        physicalStateScore,
      );
    }

    return HealthSaveData._(
      recordDate: recordDate,
      sleepDurationMinutes: sleepDurationMinutes,
      sleepDescription: normalizeMetricDescription(
        sleepDescription,
        name: 'sleepDescription',
      ),
      weightKg: weightKg,
      weightDescription: normalizeMetricDescription(
        weightDescription,
        name: 'weightDescription',
      ),
      waterIntakeMl: waterIntakeMl,
      waterDescription: normalizeMetricDescription(
        waterDescription,
        name: 'waterDescription',
      ),
      exerciseDurationMinutes: exerciseDurationMinutes,
      exerciseDescription: normalizeMetricDescription(
        exerciseDescription,
        name: 'exerciseDescription',
      ),
      exerciseType: _trimToNull(exerciseType),
      physicalStateScore: physicalStateScore,
      physicalStateDescription: _normalizeDescription(physicalStateDescription),
      note: _trimToNull(note),
    );
  }

  const HealthSaveData._({
    required this.recordDate,
    required this.sleepDurationMinutes,
    required this.sleepDescription,
    required this.weightKg,
    required this.weightDescription,
    required this.waterIntakeMl,
    required this.waterDescription,
    required this.exerciseDurationMinutes,
    required this.exerciseDescription,
    required this.exerciseType,
    required this.physicalStateScore,
    required this.physicalStateDescription,
    required this.note,
  });

  final String recordDate;
  final int? sleepDurationMinutes;
  final String? sleepDescription;
  final double? weightKg;
  final String? weightDescription;
  final int? waterIntakeMl;
  final String? waterDescription;
  final int? exerciseDurationMinutes;
  final String? exerciseDescription;
  final String? exerciseType;
  final int? physicalStateScore;
  final String? physicalStateDescription;
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

  static String? _normalizeDescription(String? value) {
    final normalized = _trimToNull(value);
    if (normalized != null && normalized.length > 80) {
      throw InvalidHealthMetricException(
        'physicalStateDescription',
        normalized,
      );
    }
    return normalized;
  }
}
