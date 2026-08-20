import 'package:rebirth/features/sync/domain/sync_models.dart';

final class HealthSyncPayload implements SyncEntityPayload {
  const HealthSyncPayload({
    required this.recordDate,
    required this.timezoneOffsetMinutes,
    required this.sleepDurationMinutes,
    this.sleepDescription,
    required this.weightKg,
    this.weightDescription,
    required this.waterIntakeMl,
    this.waterDescription,
    required this.exerciseType,
    required this.exerciseDurationMinutes,
    this.exerciseDescription,
    required this.physicalStateScore,
    this.physicalStateScoreScale = 10,
    this.physicalStateDescription,
    required this.note,
    required this.dataSource,
    required this.sourceRecordId,
    required this.createdAt,
  });

  final String recordDate;
  final int timezoneOffsetMinutes;
  final int? sleepDurationMinutes;
  final String? sleepDescription;
  final double? weightKg;
  final String? weightDescription;
  final int? waterIntakeMl;
  final String? waterDescription;
  final String? exerciseType;
  final int? exerciseDurationMinutes;
  final String? exerciseDescription;
  final int? physicalStateScore;
  final int physicalStateScoreScale;
  final String? physicalStateDescription;
  final String? note;
  final String dataSource;
  final String? sourceRecordId;
  final int createdAt;

  bool get hasMetrics =>
      sleepDurationMinutes != null ||
      sleepDescription != null ||
      weightKg != null ||
      weightDescription != null ||
      waterIntakeMl != null ||
      waterDescription != null ||
      exerciseType != null ||
      exerciseDurationMinutes != null ||
      exerciseDescription != null ||
      physicalStateScore != null ||
      physicalStateDescription != null ||
      note != null;
}
