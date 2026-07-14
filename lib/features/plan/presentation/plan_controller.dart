import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/plan/data/plan_repository_provider.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_goal_save_data.dart';

import 'plan_view_state.dart';

final planControllerProvider =
    AsyncNotifierProvider<PlanController, PlanViewState>(PlanController.new);

class PlanController extends AsyncNotifier<PlanViewState> {
  List<PlanGoal> _breadcrumbs = const [];

  @override
  Future<PlanViewState> build() {
    _breadcrumbs = const [];
    return _readCurrentView();
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
      return Future.value();
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
    final effectiveData = _withParentGoalId(data, parentGoalId);
    return _mutate(
      () => ref.read(planRepositoryProvider).createGoal(effectiveData),
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

  Future<void> deleteGoal(String id) {
    return _mutate(() => ref.read(planRepositoryProvider).softDelete(id));
  }

  String? get _currentParentGoalId {
    return _breadcrumbs.isEmpty ? null : _breadcrumbs.last.id;
  }

  Future<void> _loadCurrent() async {
    state = const AsyncLoading<PlanViewState>();
    try {
      state = AsyncData(await _readCurrentView());
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> _mutate(Future<Object?> Function() operation) async {
    await operation();
    state = AsyncData(await _readCurrentView());
  }

  Future<PlanViewState> _readCurrentView() async {
    final repository = ref.read(planRepositoryProvider);
    final parentGoalId = _currentParentGoalId;
    final goals = parentGoalId == null
        ? await repository.listRootGoals()
        : await repository.listChildren(parentGoalId);
    return PlanViewState(goals: goals, breadcrumbs: _breadcrumbs);
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
