import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/plan/data/plan_repository_provider.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_goal_save_data.dart';

final planControllerProvider =
    AsyncNotifierProvider<PlanController, List<PlanGoal>>(PlanController.new);

class PlanController extends AsyncNotifier<List<PlanGoal>> {
  String? _loadedParentGoalId;

  @override
  Future<List<PlanGoal>> build() {
    _loadedParentGoalId = null;
    return ref.watch(planRepositoryProvider).listRootGoals();
  }

  Future<void> reload() => _loadCurrent();

  Future<void> loadRootGoals() {
    _loadedParentGoalId = null;
    return _loadCurrent();
  }

  Future<void> loadChildren(String parentGoalId) {
    _loadedParentGoalId = parentGoalId;
    return _loadCurrent();
  }

  Future<void> createGoal(PlanGoalSaveData data) {
    return _mutate(() => ref.read(planRepositoryProvider).createGoal(data));
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

  Future<void> _loadCurrent() async {
    state = const AsyncLoading<List<PlanGoal>>();
    await _setFrom(_readCurrentList);
  }

  Future<void> _mutate(Future<Object?> Function() operation) async {
    try {
      await operation();
      state = AsyncData(await _readCurrentList());
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<List<PlanGoal>> _readCurrentList() {
    final repository = ref.read(planRepositoryProvider);
    final parentGoalId = _loadedParentGoalId;
    return parentGoalId == null
        ? repository.listRootGoals()
        : repository.listChildren(parentGoalId);
  }

  Future<void> _setFrom(Future<List<PlanGoal>> Function() operation) async {
    try {
      state = AsyncData(await operation());
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
