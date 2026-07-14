import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_goal_lifecycle.dart';
import 'package:rebirth/features/plan/presentation/widgets/plan_goal_labels.dart';

void main() {
  const today = '2026-07-14';

  test('archived goal takes precedence over every other lifecycle', () {
    expect(
      computePlanGoalLifecycle(
        goal: _goal(
          archivedAt: 1,
          status: PlanGoalStatus.completed,
          startDate: '2027-01-01',
        ),
        today: today,
      ),
      PlanGoalLifecycle.archived,
    );
  });

  test('completed status maps to completed', () {
    expect(
      computePlanGoalLifecycle(
        goal: _goal(status: PlanGoalStatus.completed),
        today: today,
      ),
      PlanGoalLifecycle.completed,
    );
  });

  test('future start date maps to not started', () {
    expect(
      computePlanGoalLifecycle(
        goal: _goal(startDate: '2026-07-15'),
        today: today,
      ),
      PlanGoalLifecycle.notStarted,
    );
  });

  test('started goal with current or future target is in progress', () {
    for (final target in ['2026-07-14', '2026-08-01']) {
      expect(
        computePlanGoalLifecycle(
          goal: _goal(startDate: '2026-07-01', targetDate: target),
          today: today,
        ),
        PlanGoalLifecycle.inProgress,
      );
    }
  });

  test('past target maps to overdue', () {
    expect(
      computePlanGoalLifecycle(
        goal: _goal(startDate: '2026-06-01', targetDate: '2026-07-13'),
        today: today,
      ),
      PlanGoalLifecycle.overdue,
    );
  });

  test('started goal without target remains in progress', () {
    expect(
      computePlanGoalLifecycle(
        goal: _goal(startDate: '2026-07-01'),
        today: today,
      ),
      PlanGoalLifecycle.inProgress,
    );
  });

  test('lifecycle labels are stable Chinese display values', () {
    const expected = <PlanGoalLifecycle, String>{
      PlanGoalLifecycle.notStarted: '未开始',
      PlanGoalLifecycle.inProgress: '进行中',
      PlanGoalLifecycle.overdue: '已过期',
      PlanGoalLifecycle.completed: '已完成',
      PlanGoalLifecycle.archived: '已归档',
    };
    for (final entry in expected.entries) {
      expect(planGoalLifecycleLabel(entry.key), entry.value);
    }
  });
}

PlanGoal _goal({
  PlanGoalStatus status = PlanGoalStatus.inProgress,
  String? startDate,
  String? targetDate,
  int? archivedAt,
}) {
  return PlanGoal(
    id: 'goal',
    userId: 'user',
    parentGoalId: null,
    title: '目标',
    description: null,
    goalLevel: PlanGoalLevel.month,
    status: status,
    startDate: startDate,
    targetDate: targetDate,
    completedAt: status == PlanGoalStatus.completed ? 1 : null,
    archivedAt: archivedAt,
    sortOrder: 0,
    createdAt: 1,
    updatedAt: 1,
  );
}
