import 'package:rebirth/features/sync/domain/sync_models.dart';

import 'today_entry.dart';

final class TodaySyncPayload implements SyncEntityPayload {
  const TodaySyncPayload({
    required this.recordDate,
    required this.timezoneOffsetMinutes,
    required this.priority1,
    required this.priority1Completed,
    required this.priority1GoalId,
    required this.priority2,
    required this.priority2Completed,
    required this.priority2GoalId,
    required this.priority3,
    required this.priority3Completed,
    required this.priority3GoalId,
    required this.moodScore,
    this.wellbeingScoreScale = 10,
    this.moodDescription,
    required this.energyScore,
    this.energyDescription,
    required this.researchMinutes,
    required this.learningMinutes,
    required this.dailyNote,
    required this.status,
    required this.createdAt,
  });

  final String recordDate;
  final int timezoneOffsetMinutes;
  final String? priority1;
  final bool priority1Completed;
  final String? priority1GoalId;
  final String? priority2;
  final bool priority2Completed;
  final String? priority2GoalId;
  final String? priority3;
  final bool priority3Completed;
  final String? priority3GoalId;
  final int? moodScore;
  final int wellbeingScoreScale;
  final String? moodDescription;
  final int? energyScore;
  final String? energyDescription;
  final int? researchMinutes;
  final int? learningMinutes;
  final String? dailyNote;
  final TodayRecordStatus status;
  final int createdAt;
}
