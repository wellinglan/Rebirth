enum PlanGoalLevel { life, year, quarter, month, week, day }

enum PlanGoalStatus { notStarted, inProgress, completed, paused, cancelled }

extension PlanGoalLevelDatabaseValue on PlanGoalLevel {
  String get databaseValue => name;
}

extension PlanGoalStatusDatabaseValue on PlanGoalStatus {
  String get databaseValue => switch (this) {
    PlanGoalStatus.notStarted => 'not_started',
    PlanGoalStatus.inProgress => 'in_progress',
    PlanGoalStatus.completed => 'completed',
    PlanGoalStatus.paused => 'paused',
    PlanGoalStatus.cancelled => 'cancelled',
  };
}

PlanGoalLevel planGoalLevelFromDatabase(String value) {
  return switch (value) {
    'life' => PlanGoalLevel.life,
    'year' => PlanGoalLevel.year,
    'quarter' => PlanGoalLevel.quarter,
    'month' => PlanGoalLevel.month,
    'week' => PlanGoalLevel.week,
    'day' => PlanGoalLevel.day,
    _ => throw StateError('Unknown plan goal level: $value'),
  };
}

PlanGoalStatus planGoalStatusFromDatabase(String value) {
  return switch (value) {
    'not_started' => PlanGoalStatus.notStarted,
    'in_progress' => PlanGoalStatus.inProgress,
    'completed' => PlanGoalStatus.completed,
    'paused' => PlanGoalStatus.paused,
    'cancelled' => PlanGoalStatus.cancelled,
    _ => throw StateError('Unknown plan goal status: $value'),
  };
}

final class PlanGoal {
  const PlanGoal({
    required this.id,
    required this.userId,
    required this.parentGoalId,
    required this.title,
    required this.description,
    required this.goalLevel,
    required this.status,
    required this.startDate,
    required this.targetDate,
    required this.completedAt,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String? parentGoalId;
  final String title;
  final String? description;
  final PlanGoalLevel goalLevel;
  final PlanGoalStatus status;
  final String? startDate;
  final String? targetDate;
  final int? completedAt;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;
}
