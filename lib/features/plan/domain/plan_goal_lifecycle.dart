import 'plan_goal.dart';

enum PlanGoalLifecycle { notStarted, inProgress, overdue, completed, archived }

PlanGoalLifecycle computePlanGoalLifecycle({
  required PlanGoal goal,
  required String today,
}) {
  if (goal.archivedAt != null) {
    return PlanGoalLifecycle.archived;
  }
  if (goal.status == PlanGoalStatus.completed) {
    return PlanGoalLifecycle.completed;
  }
  if (goal.startDate case final startDate?
      when startDate.compareTo(today) > 0) {
    return PlanGoalLifecycle.notStarted;
  }
  if (goal.targetDate case final targetDate?
      when targetDate.compareTo(today) < 0) {
    return PlanGoalLifecycle.overdue;
  }
  return PlanGoalLifecycle.inProgress;
}
