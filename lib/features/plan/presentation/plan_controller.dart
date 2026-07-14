import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/plan/data/plan_repository_provider.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_goal_lifecycle.dart';
import 'package:rebirth/features/plan/domain/plan_goal_save_data.dart';

import 'plan_filter_state.dart';
import 'plan_view_state.dart';

final planControllerProvider =
    AsyncNotifierProvider<PlanController, PlanViewState>(PlanController.new);

class PlanController extends AsyncNotifier<PlanViewState> {
  List<PlanGoal> _breadcrumbs = const [];
  List<PlanGoal> _allGoals = const [];
  PlanFilterState _filter = const PlanFilterState();
  String _today = '';

  @override
  Future<PlanViewState> build() async {
    _breadcrumbs = const [];
    _filter = const PlanFilterState();
    await _readCurrentGoals();
    return _buildView();
  }

  Future<void> reload() => _loadCurrent();

  Future<void> loadRootGoals() {
    _breadcrumbs = const [];
    return _loadCurrent();
  }

  Future<void> openChildren(PlanGoal parent) {
    _breadcrumbs = [..._breadcrumbs, parent];
    return _loadCurrent();
  }

  Future<void> navigateBack() {
    if (_breadcrumbs.isEmpty) {
      return Future<void>.value();
    }
    _breadcrumbs = _breadcrumbs.sublist(0, _breadcrumbs.length - 1);
    return _loadCurrent();
  }

  Future<void> navigateToBreadcrumb(int index) {
    if (index < -1 || index >= _breadcrumbs.length) {
      throw RangeError.index(index, _breadcrumbs, 'index');
    }
    _breadcrumbs = index == -1 ? const [] : _breadcrumbs.sublist(0, index + 1);
    return _loadCurrent();
  }

  Future<void> createGoal(PlanGoalSaveData data) {
    final parentGoalId = data.parentGoalId ?? _currentParentGoalId;
    return _mutate(
      () => ref
          .read(planRepositoryProvider)
          .createGoal(_withParentGoalId(data, parentGoalId)),
    );
  }

  Future<void> updateGoal({
    required String id,
    required PlanGoalSaveData data,
  }) {
    return _mutate(
      () => ref.read(planRepositoryProvider).updateGoal(id: id, data: data),
    );
  }

  Future<void> updateStatus({
    required String id,
    required PlanGoalStatus status,
  }) {
    return _mutate(
      () =>
          ref.read(planRepositoryProvider).updateStatus(id: id, status: status),
    );
  }

  Future<void> updateCompletion({required String id, required bool completed}) {
    return _mutate(
      () => ref
          .read(planRepositoryProvider)
          .updateCompletion(id: id, completed: completed),
    );
  }

  Future<void> archiveGoal(String id) {
    return _mutate(() => ref.read(planRepositoryProvider).archiveGoal(id));
  }

  Future<void> restoreGoal(String id) {
    return _mutate(() => ref.read(planRepositoryProvider).restoreGoal(id));
  }

  Future<void> deleteGoal(String id) {
    return _mutate(() => ref.read(planRepositoryProvider).softDelete(id));
  }

  Future<void> updateFilter(PlanFilterState filter) async {
    final previousFilter = _filter;
    final previousGoals = _allGoals;
    _filter = filter;
    try {
      if (filter.includeArchived != previousFilter.includeArchived) {
        await _readCurrentGoals();
      }
      state = AsyncData(_buildView());
    } catch (_) {
      _filter = previousFilter;
      _allGoals = previousGoals;
      rethrow;
    }
  }

  Future<void> updateSortMode(PlanSortMode sortMode) {
    return updateFilter(_filter.copyWith(sortMode: sortMode));
  }

  Future<void> toggleIncludeArchived(bool value) {
    return updateFilter(_filter.copyWith(includeArchived: value));
  }

  String? get _currentParentGoalId {
    return _breadcrumbs.isEmpty ? null : _breadcrumbs.last.id;
  }

  Future<void> _loadCurrent() async {
    state = const AsyncLoading<PlanViewState>();
    try {
      await _readCurrentGoals();
      state = AsyncData(_buildView());
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> _mutate(Future<Object?> Function() operation) async {
    await operation();
    await _readCurrentGoals();
    state = AsyncData(_buildView());
  }

  Future<void> _readCurrentGoals() async {
    final repository = ref.read(planRepositoryProvider);
    final parentGoalId = _currentParentGoalId;
    _allGoals = parentGoalId == null
        ? await repository.listRootGoals(
            includeArchived: _filter.includeArchived,
          )
        : await repository.listChildren(
            parentGoalId,
            includeArchived: _filter.includeArchived,
          );
    _today = ref.read(dateTimeServiceProvider).currentLocalDateString();
  }

  PlanViewState _buildView() {
    final goals = _allGoals.where(_matchesFilter).toList(growable: false)
      ..sort(_compareGoals);
    return PlanViewState(
      goals: goals,
      breadcrumbs: _breadcrumbs,
      filter: _filter,
      today: _today,
      hasUnfilteredGoals: _allGoals.isNotEmpty,
    );
  }

  bool _matchesFilter(PlanGoal goal) {
    if (_filter.level != null && goal.goalLevel != _filter.level) {
      return false;
    }
    final lifecycle = computePlanGoalLifecycle(goal: goal, today: _today);
    return switch (_filter.lifecycle) {
      PlanLifecycleFilter.all => true,
      PlanLifecycleFilter.notStarted =>
        lifecycle == PlanGoalLifecycle.notStarted,
      PlanLifecycleFilter.inProgress =>
        lifecycle == PlanGoalLifecycle.inProgress,
      PlanLifecycleFilter.overdue => lifecycle == PlanGoalLifecycle.overdue,
      PlanLifecycleFilter.completed => lifecycle == PlanGoalLifecycle.completed,
      PlanLifecycleFilter.archived => lifecycle == PlanGoalLifecycle.archived,
    };
  }

  int _compareGoals(PlanGoal left, PlanGoal right) {
    return switch (_filter.sortMode) {
      PlanSortMode.priorityAsc => _then(
        left.sortOrder.compareTo(right.sortOrder),
        left,
        right,
      ),
      PlanSortMode.targetDateAsc => _compareTargetDates(left, right),
      PlanSortMode.createdAtDesc => right.createdAt.compareTo(left.createdAt),
      PlanSortMode.levelThenPriority => _then(
        left.goalLevel.index.compareTo(right.goalLevel.index),
        left,
        right,
      ),
    };
  }

  int _compareTargetDates(PlanGoal left, PlanGoal right) {
    final leftDate = left.targetDate;
    final rightDate = right.targetDate;
    if (leftDate == null && rightDate == null) {
      return _then(0, left, right);
    }
    if (leftDate == null) return 1;
    if (rightDate == null) return -1;
    return _then(leftDate.compareTo(rightDate), left, right);
  }

  int _then(int comparison, PlanGoal left, PlanGoal right) {
    return comparison != 0
        ? comparison
        : left.createdAt.compareTo(right.createdAt);
  }

  PlanGoalSaveData _withParentGoalId(
    PlanGoalSaveData data,
    String? parentGoalId,
  ) {
    return PlanGoalSaveData(
      parentGoalId: parentGoalId,
      title: data.title,
      description: data.description,
      goalLevel: data.goalLevel,
      status: data.status,
      startDate: data.startDate,
      targetDate: data.targetDate,
      sortOrder: data.sortOrder,
    );
  }
}
