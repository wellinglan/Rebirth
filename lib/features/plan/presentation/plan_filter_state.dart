import 'package:rebirth/features/plan/domain/plan_goal.dart';

enum PlanLifecycleFilter {
  all,
  notStarted,
  inProgress,
  overdue,
  completed,
  archived,
}

enum PlanSortMode {
  priorityAsc,
  targetDateAsc,
  createdAtDesc,
  levelThenPriority,
}

final class PlanFilterState {
  const PlanFilterState({
    this.level,
    this.lifecycle = PlanLifecycleFilter.all,
    this.sortMode = PlanSortMode.priorityAsc,
    this.includeArchived = false,
  });

  final PlanGoalLevel? level;
  final PlanLifecycleFilter lifecycle;
  final PlanSortMode sortMode;
  final bool includeArchived;

  PlanFilterState copyWith({
    Object? level = _unchanged,
    PlanLifecycleFilter? lifecycle,
    PlanSortMode? sortMode,
    bool? includeArchived,
  }) {
    return PlanFilterState(
      level: identical(level, _unchanged)
          ? this.level
          : level as PlanGoalLevel?,
      lifecycle: lifecycle ?? this.lifecycle,
      sortMode: sortMode ?? this.sortMode,
      includeArchived: includeArchived ?? this.includeArchived,
    );
  }
}

const _unchanged = Object();
