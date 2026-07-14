final class HealthEntry {
  const HealthEntry({
    required this.id,
    required this.userId,
    required this.todayRecordId,
    required this.recordDate,
    required this.sleepDurationMinutes,
    required this.weightKg,
    required this.waterIntakeMl,
    required this.exerciseDurationMinutes,
    required this.exerciseType,
    required this.physicalStateScore,
    required this.note,
    required this.timezoneOffsetMinutes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String? todayRecordId;
  final String recordDate;
  final int? sleepDurationMinutes;
  final double? weightKg;
  final int? waterIntakeMl;
  final int? exerciseDurationMinutes;
  final String? exerciseType;
  final int? physicalStateScore;
  final String? note;
  final int timezoneOffsetMinutes;
  final int createdAt;
  final int updatedAt;

  bool get hasMetrics =>
      sleepDurationMinutes != null ||
      weightKg != null ||
      waterIntakeMl != null ||
      exerciseDurationMinutes != null ||
      exerciseType != null ||
      physicalStateScore != null ||
      note != null;
}
