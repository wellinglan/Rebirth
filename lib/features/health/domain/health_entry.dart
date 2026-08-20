final class HealthEntry {
  const HealthEntry({
    required this.id,
    required this.userId,
    required this.todayRecordId,
    required this.recordDate,
    required this.sleepDurationMinutes,
    this.sleepDescription,
    required this.weightKg,
    this.weightDescription,
    required this.waterIntakeMl,
    this.waterDescription,
    required this.exerciseDurationMinutes,
    this.exerciseDescription,
    required this.exerciseType,
    required this.physicalStateScore,
    this.physicalStateDescription,
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
  final int timezoneOffsetMinutes;
  final int createdAt;
  final int updatedAt;

  bool get hasMetrics =>
      sleepDurationMinutes != null ||
      (sleepDescription?.trim().isNotEmpty ?? false) ||
      weightKg != null ||
      (weightDescription?.trim().isNotEmpty ?? false) ||
      waterIntakeMl != null ||
      (waterDescription?.trim().isNotEmpty ?? false) ||
      exerciseDurationMinutes != null ||
      (exerciseDescription?.trim().isNotEmpty ?? false) ||
      exerciseType != null ||
      physicalStateScore != null ||
      physicalStateDescription != null ||
      note != null;
}
