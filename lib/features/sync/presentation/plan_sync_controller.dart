import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/plan/presentation/plan_controller.dart';
import 'package:rebirth/features/sync/data/sync_providers.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

import 'plan_sync_view_state.dart';

final planSyncControllerProvider =
    NotifierProvider<PlanSyncController, PlanSyncViewState>(
      PlanSyncController.new,
    );

typedef PlanSyncRunner = Future<SyncRunResult> Function();
typedef PlanViewRefresher = Future<void> Function();

final planSyncRunnerProvider = Provider<PlanSyncRunner>((ref) {
  return () => ref
      .read(syncCoordinatorProvider)
      .run(
        direction: SyncRunDirection.twoWay,
        entityTypes: const [SyncEntityType.plan],
      );
});

final planViewRefresherProvider = Provider<PlanViewRefresher>((ref) {
  return () => ref.read(planControllerProvider.notifier).reload();
});

class PlanSyncController extends Notifier<PlanSyncViewState> {
  Future<SyncRunResult>? _active;

  @override
  PlanSyncViewState build() => const PlanSyncViewState();

  Future<SyncRunResult> syncPlan() {
    final active = _active;
    if (active != null) return active;
    final future = _run();
    _active = future;
    future.then<void>(
      (_) => _clearActive(future),
      onError: (Object _, StackTrace _) => _clearActive(future),
    );
    return future;
  }

  Future<SyncRunResult> _run() async {
    state = PlanSyncViewState(
      status: PlanSyncStatus.syncing,
      lastResult: state.lastResult,
    );
    try {
      final result = await ref.read(planSyncRunnerProvider)();
      final entity = result.resultFor(SyncEntityType.plan);
      final status = result.isSuccessful
          ? PlanSyncStatus.succeeded
          : entity?.status == SyncEntityStatus.conflict
          ? PlanSyncStatus.conflict
          : PlanSyncStatus.failed;
      if (ref.mounted) {
        state = PlanSyncViewState(status: status, lastResult: result);
        if (result.isSuccessful) {
          await ref.read(planViewRefresherProvider)();
        }
      }
      return result;
    } catch (_) {
      if (ref.mounted) {
        state = PlanSyncViewState(
          status: PlanSyncStatus.failed,
          lastResult: state.lastResult,
          errorMessage: 'Plan 同步失败，本地数据未受影响',
        );
      }
      rethrow;
    }
  }

  void _clearActive(Future<SyncRunResult> completed) {
    if (identical(_active, completed)) _active = null;
  }
}
