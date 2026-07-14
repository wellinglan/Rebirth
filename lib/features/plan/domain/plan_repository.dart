import 'plan_goal.dart';
import 'plan_goal_save_data.dart';

final class PlanGoalNotFoundException implements Exception {
  const PlanGoalNotFoundException(this.id);

  final String id;

  @override
  String toString() => 'No active plan goal exists with ID $id.';
}

final class InvalidPlanGoalParentException implements Exception {
  const InvalidPlanGoalParentException(this.id);

  final String id;

  @override
  String toString() => 'A plan goal cannot be its own parent: $id.';
}

abstract interface class PlanRepository {
  Future<PlanGoal> createGoal(PlanGoalSaveData data);

  Future<PlanGoal?> getById(String id);

  Future<List<PlanGoal>> listGoals({
    PlanGoalLevel? level,
    PlanGoalStatus? status,
    String? parentGoalId,
    bool includeArchived = false,
  });

  Future<List<PlanGoal>> listRootGoals({bool includeArchived = false});

  Future<List<PlanGoal>> listChildren(
    String parentGoalId, {
    bool includeArchived = false,
  });

  Future<PlanGoal> updateGoal({
    required String id,
    required PlanGoalSaveData data,
  });

  Future<PlanGoal> updateStatus({
    required String id,
    required PlanGoalStatus status,
  });

  Future<PlanGoal> updateCompletion({
    required String id,
    required bool completed,
  });

  Future<void> archiveGoal(String id);

  Future<void> restoreGoal(String id);

  Future<void> softDelete(String id);
}
