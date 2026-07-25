import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/plan/presentation/plan_controller.dart';
import 'package:rebirth/features/sync/data/sync_conflict_providers.dart';
import 'package:rebirth/features/sync/data/sync_providers.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
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

final planPullRunnerProvider = Provider<PlanSyncRunner>((ref) {
  return () => ref
      .read(syncCoordinatorProvider)
      .run(
        direction: SyncRunDirection.pull,
        entityTypes: const [SyncEntityType.plan],
      );
});

final planPushRunnerProvider = Provider<PlanSyncRunner>((ref) {
  return () => ref
      .read(syncCoordinatorProvider)
      .run(
        direction: SyncRunDirection.push,
        entityTypes: const [SyncEntityType.plan],
      );
});

final planViewRefresherProvider = Provider<PlanViewRefresher>((ref) {
  return () => ref.read(planControllerProvider.notifier).reload();
});

class PlanSyncController extends Notifier<PlanSyncViewState> {
  Future<SyncRunResult>? _active;
  String? _activeOperation;

  @override
  PlanSyncViewState build() => const PlanSyncViewState();

  Future<SyncRunResult> syncPlan() {
    return _start('sync', _runSync);
  }

  Future<SyncRunResult> retryConflictHydration(String conflictId) {
    return _start(
      'hydrate:$conflictId',
      () => _runConflictAction(
        conflictId: conflictId,
        status: PlanSyncStatus.hydratingConflict,
        prepare: null,
        runner: ref.read(planPullRunnerProvider),
      ),
    );
  }

  Future<SyncRunResult> adoptRemote(String conflictId) {
    return _start(
      'adopt:$conflictId',
      () => _runConflictAction(
        conflictId: conflictId,
        status: PlanSyncStatus.adoptingRemote,
        prepare: (scope) => ref
            .read(planConflictResolutionServiceProvider)
            .requestAdoptRemote(scope: scope, conflictId: conflictId),
        runner: ref.read(planPullRunnerProvider),
      ),
    );
  }

  Future<SyncRunResult> keepLocal(String conflictId) {
    return _start(
      'keep:$conflictId',
      () => _runConflictAction(
        conflictId: conflictId,
        status: PlanSyncStatus.keepingLocal,
        prepare: (scope) => ref
            .read(planConflictResolutionServiceProvider)
            .requestKeepLocal(scope: scope, conflictId: conflictId),
        runner: ref.read(planPushRunnerProvider),
      ),
    );
  }

  Future<SyncRunResult> retryRequestedResolution(String conflictId) async {
    final scope = await _requireScope();
    final conflict = await ref
        .read(syncConflictRepositoryProvider)
        .getConflict(scope, conflictId);
    return switch (conflict.resolutionStatus) {
      SyncConflictResolutionStatus.adoptRemoteRequested =>
        retryConflictHydration(conflictId),
      SyncConflictResolutionStatus.keepLocalRequested => _start(
        'keep:$conflictId',
        () => _runConflictAction(
          conflictId: conflictId,
          status: PlanSyncStatus.keepingLocal,
          prepare: null,
          runner: ref.read(planPushRunnerProvider),
        ),
      ),
      _ => throw const SyncException('该冲突当前没有可重试的解决操作。'),
    };
  }

  Future<void> reloadConflictCount() async {
    if (!ref.mounted) return;
    try {
      final scope = await ref.read(syncConflictScopeProvider.future);
      if (!ref.mounted) return;
      final count = scope == null
          ? 0
          : (await ref
                    .read(syncConflictRepositoryProvider)
                    .listActiveConflicts(scope))
                .length;
      if (!ref.mounted) return;
      state = state.copyWith(activeConflictCount: count);
      ref.invalidate(activeSyncConflictCountProvider);
      ref.invalidate(activeSyncConflictListProvider);
    } catch (_) {
      // Conflict count is auxiliary; a storage/bootstrap failure must not turn
      // an otherwise successful Plan sync into a failed sync.
    }
  }

  Future<SyncRunResult> _start(
    String operation,
    Future<SyncRunResult> Function() run,
  ) {
    final active = _active;
    if (active != null) {
      if (_activeOperation == operation) return active;
      throw const SyncException('已有其他同步操作正在进行。');
    }
    final future = run();
    _active = future;
    _activeOperation = operation;
    future.then<void>(
      (_) => _clearActive(future),
      onError: (Object _, StackTrace _) => _clearActive(future),
    );
    return future;
  }

  Future<SyncRunResult> _runSync() async {
    state = state.copyWith(
      status: PlanSyncStatus.syncing,
      clearError: true,
      clearResolvingConflictId: true,
    );
    try {
      var result = await ref.read(planSyncRunnerProvider)();
      await reloadConflictCount();
      final planResult = result.resultFor(SyncEntityType.plan);
      final shouldHydrate =
          !result.isSuccessful &&
          planResult?.status == SyncEntityStatus.conflict;
      final awaiting = shouldHydrate
          ? await _awaitingConflicts()
          : const <SyncConflictRecord>[];
      if (awaiting.isNotEmpty) {
        if (ref.mounted) {
          state = state.copyWith(
            status: PlanSyncStatus.hydratingConflict,
            lastResult: result,
          );
        }
        await Future<void>.delayed(Duration.zero);
        result = await ref.read(planPullRunnerProvider)();
        await reloadConflictCount();
      }
      await _finishWithResult(result);
      return result;
    } catch (_) {
      _showFailure('Plan 同步失败，本地数据未受影响');
      rethrow;
    }
  }

  Future<SyncRunResult> _runConflictAction({
    required String conflictId,
    required PlanSyncStatus status,
    required Future<void> Function(SyncConflictScope scope)? prepare,
    required PlanSyncRunner runner,
  }) async {
    state = state.copyWith(
      status: status,
      resolvingConflictId: conflictId,
      clearError: true,
    );
    try {
      final scope = await _requireScope();
      if (prepare != null) await prepare(scope);
      await Future<void>.delayed(Duration.zero);
      final result = await runner();
      await reloadConflictCount();
      ref.invalidate(syncConflictDetailsProvider(conflictId));
      await _finishWithResult(result, refreshPlan: result.isSuccessful);
      return result;
    } catch (_) {
      await reloadConflictCount();
      _showFailure('冲突处理失败，本地 Plan 内容已保留');
      rethrow;
    }
  }

  Future<List<SyncConflictRecord>> _awaitingConflicts() async {
    if (!ref.mounted) return const [];
    try {
      final scope = await ref.read(syncConflictScopeProvider.future);
      if (scope == null || !ref.mounted) return const [];
      final records = await ref
          .read(syncConflictRepositoryProvider)
          .listActiveConflicts(scope);
      return records
          .where(
            (item) =>
                item.resolutionStatus ==
                SyncConflictResolutionStatus.awaitingRemoteSnapshot,
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<SyncConflictScope> _requireScope() async {
    final scope = await ref.read(syncConflictScopeProvider.future);
    if (scope == null) {
      throw const SyncException('请先登录当前 Endpoint 的云账号。');
    }
    return scope;
  }

  Future<void> _finishWithResult(
    SyncRunResult result, {
    bool refreshPlan = true,
  }) async {
    final entity = result.resultFor(SyncEntityType.plan);
    final status = result.isSuccessful
        ? PlanSyncStatus.succeeded
        : entity?.status == SyncEntityStatus.conflict
        ? PlanSyncStatus.conflict
        : PlanSyncStatus.failed;
    if (!ref.mounted) return;
    state = state.copyWith(
      status: status,
      lastResult: result,
      clearResolvingConflictId: true,
    );
    if (refreshPlan && result.isSuccessful) {
      await ref.read(planViewRefresherProvider)();
    }
  }

  void _showFailure(String message) {
    if (!ref.mounted) return;
    state = state.copyWith(
      status: PlanSyncStatus.failed,
      errorMessage: message,
      clearResolvingConflictId: true,
    );
  }

  void _clearActive(Future<SyncRunResult> completed) {
    if (identical(_active, completed)) {
      _active = null;
      _activeOperation = null;
    }
  }
}
