import 'package:rebirth/features/plan/domain/plan_goal.dart';

final class PlanViewState {
  PlanViewState({
    required List<PlanGoal> goals,
    required List<PlanGoal> breadcrumbs,
  }) : goals = List.unmodifiable(goals),
       breadcrumbs = List.unmodifiable(breadcrumbs);

  final List<PlanGoal> goals;
  final List<PlanGoal> breadcrumbs;

  PlanGoal? get currentParent => breadcrumbs.isEmpty ? null : breadcrumbs.last;

  String? get currentParentGoalId => currentParent?.id;

  bool get isRoot => breadcrumbs.isEmpty;
}
