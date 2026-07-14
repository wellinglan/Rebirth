import 'health_entry.dart';

final class HealthSummary {
  const HealthSummary({
    required this.days,
    required this.recordsCount,
    required this.averageSleepMinutes,
    required this.totalExerciseMinutes,
    required this.averageWaterIntakeMl,
    required this.latestWeightKg,
    required this.latestPhysicalStateScore,
  });

  factory HealthSummary.fromEntries({
    required int days,
    required List<HealthEntry> entries,
  }) {
    if (days <= 0) {
      throw ArgumentError.value(days, 'days', 'Days must be positive.');
    }

    final sleepValues = entries
        .map((entry) => entry.sleepDurationMinutes)
        .whereType<int>()
        .toList(growable: false);
    final waterValues = entries
        .map((entry) => entry.waterIntakeMl)
        .whereType<int>()
        .toList(growable: false);
    final exerciseValues = entries
        .map((entry) => entry.exerciseDurationMinutes)
        .whereType<int>()
        .toList(growable: false);

    return HealthSummary(
      days: days,
      recordsCount: entries.length,
      averageSleepMinutes: _average(sleepValues),
      totalExerciseMinutes: exerciseValues.isEmpty
          ? null
          : exerciseValues.reduce((first, second) => first + second),
      averageWaterIntakeMl: _average(waterValues),
      latestWeightKg: _latest(entries, (entry) => entry.weightKg),
      latestPhysicalStateScore: _latest(
        entries,
        (entry) => entry.physicalStateScore,
      ),
    );
  }

  final int days;
  final int recordsCount;
  final double? averageSleepMinutes;
  final int? totalExerciseMinutes;
  final double? averageWaterIntakeMl;
  final double? latestWeightKg;
  final int? latestPhysicalStateScore;

  bool get hasData => recordsCount > 0;

  static double? _average(List<int> values) {
    if (values.isEmpty) {
      return null;
    }
    return values.reduce((first, second) => first + second) / values.length;
  }

  static T? _latest<T>(
    List<HealthEntry> entries,
    T? Function(HealthEntry entry) valueOf,
  ) {
    for (final entry in entries) {
      final value = valueOf(entry);
      if (value != null) {
        return value;
      }
    }
    return null;
  }
}
