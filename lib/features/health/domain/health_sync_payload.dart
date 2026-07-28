import 'package:rebirth/features/sync/domain/sync_models.dart';

final class HealthSyncPayload implements SyncEntityPayload {
  const HealthSyncPayload({
    required this.recordDate,
    required this.timezoneOffsetMinutes,
    required this.sleepDurationMinutes,
    required this.weightKg,
    required this.waterIntakeMl,
    required this.exerciseType,
    required this.exerciseDurationMinutes,
    required this.physicalStateScore,
    required this.note,
    required this.dataSource,
    required this.sourceRecordId,
    required this.createdAt,
  });

  final String recordDate;
  final int timezoneOffsetMinutes;
  final int? sleepDurationMinutes;
  final double? weightKg;
  final int? waterIntakeMl;
  final String? exerciseType;
  final int? exerciseDurationMinutes;
  final int? physicalStateScore;
  final String? note;
  final String dataSource;
  final String? sourceRecordId;
  final int createdAt;

  bool get hasMetrics =>
      sleepDurationMinutes != null ||
      weightKg != null ||
      waterIntakeMl != null ||
      exerciseType != null ||
      exerciseDurationMinutes != null ||
      physicalStateScore != null ||
      note != null;
}
