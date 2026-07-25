import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

final class PlanSyncPayload implements SyncEntityPayload {
  const PlanSyncPayload({
    required this.parentGoalId,
    required this.title,
    required this.description,
    required this.goalLevel,
    required this.status,
    required this.startDate,
    required this.targetDate,
    required this.completedAt,
    required this.archivedAt,
    required this.sortOrder,
    required this.createdAt,
  });

  final String? parentGoalId;
  final String title;
  final String? description;
  final PlanGoalLevel goalLevel;
  final PlanGoalStatus status;
  final String? startDate;
  final String? targetDate;
  final int? completedAt;
  final int? archivedAt;
  final int sortOrder;
  final int createdAt;
}
