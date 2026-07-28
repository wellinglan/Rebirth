import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/health/presentation/health_controller.dart';
import 'package:rebirth/features/sync/data/sync_conflict_providers.dart';
import 'package:rebirth/features/sync/data/sync_providers.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

import 'health_sync_view_state.dart';

final healthSyncControllerProvider =
    NotifierProvider<HealthSyncController, HealthSyncViewState>(
      HealthSyncController.new,
    );

typedef HealthSyncRunner = Future<SyncRunResult> Function();
typedef HealthViewRefresher = Future<void> Function();

final healthSyncRunnerProvider = Provider<HealthSyncRunner>((ref) {
  return () => ref
      .read(syncCoordinatorProvider)
      .run(
        direction: SyncRunDirection.twoWay,
        entityTypes: const [SyncEntityType.health],
      );
});

final healthConflictPullRunnerProvider = Provider<HealthSyncRunner>((ref) {
  return () => ref
      .read(syncCoordinatorProvider)
      .run(
        direction: SyncRunDirection.pull,
        entityTypes: const [SyncEntityType.health],
        pullMode: SyncPullMode.preferRemoteConflictResolution,
      );
});

final healthPushRunnerProvider = Provider<HealthSyncRunner>((ref) {
  return () => ref
      .read(syncCoordinatorProvider)
      .run(
        direction: SyncRunDirection.push,
        entityTypes: const [SyncEntityType.health],
      );
});

final healthViewRefresherProvider = Provider<HealthViewRefresher>((ref) {
  return () => ref.read(healthControllerProvider.notifier).reload();
});

class HealthSyncController extends Notifier<HealthSyncViewState> {
  Future<SyncRunResult>? _active;
  String? _activeOperation;

  @override
  HealthSyncViewState build() => const HealthSyncViewState();

  Future<SyncRunResult> syncHealth() => _start('sync', _runSync);

  Future<SyncRunResult> retryConflictHydration(String conflictId) {
    return _start(
      'hydrate:$conflictId',
      () => _runConflictAction(
        conflictId: conflictId,
        status: HealthSyncStatus.hydratingConflict,
        prepare: null,
        runner: ref.read(healthConflictPullRunnerProvider),
      ),
    );
  }

  Future<SyncRunResult> adoptRemote(String conflictId) {
    return _start(
      'adopt:$conflictId',
      () => _runConflictAction(
        conflictId: conflictId,
        status: HealthSyncStatus.adoptingRemote,
        prepare: (scope) => ref
            .read(healthConflictResolutionServiceProvider)
            .requestAdoptRemote(scope: scope, conflictId: conflictId),
        runner: ref.read(healthConflictPullRunnerProvider),
      ),
    );
  }

  Future<SyncRunResult> keepLocal(String conflictId) {
    return _start(
      'keep:$conflictId',
      () => _runConflictAction(
        conflictId: conflictId,
        status: HealthSyncStatus.keepingLocal,
        prepare: (scope) => ref
            .read(healthConflictResolutionServiceProvider)
            .requestKeepLocal(scope: scope, conflictId: conflictId),
        runner: ref.read(healthPushRunnerProvider),
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
          status: HealthSyncStatus.keepingLocal,
          prepare: null,
          runner: ref.read(healthPushRunnerProvider),
        ),
      ),
      _ => throw const SyncException('该冲突当前没有可重试的解决操作。'),
    };
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
    state = state.copyWith(status: HealthSyncStatus.syncing, clearError: true);
    try {
      var result = await ref.read(healthSyncRunnerProvider)();
      final entity = result.resultFor(SyncEntityType.health);
      if (!result.isSuccessful &&
          entity?.status == SyncEntityStatus.conflict &&
          await _hasAwaitingRemoteSnapshot()) {
        if (ref.mounted) {
          state = state.copyWith(status: HealthSyncStatus.hydratingConflict);
        }
        result = await ref.read(healthConflictPullRunnerProvider)();
      }
      await reloadConflictCount();
      final finalEntity = result.resultFor(SyncEntityType.health);
      final status = result.isSuccessful
          ? HealthSyncStatus.succeeded
          : finalEntity?.status == SyncEntityStatus.conflict
          ? HealthSyncStatus.conflict
          : HealthSyncStatus.failed;
      if (ref.mounted) {
        state = state.copyWith(status: status, lastResult: result);
      }
      if (result.isSuccessful) {
        await ref.read(healthViewRefresherProvider)();
      }
      return result;
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          status: HealthSyncStatus.failed,
          errorMessage: 'Health 同步失败，本地数据未受影响',
        );
      }
      rethrow;
    }
  }

  Future<SyncRunResult> _runConflictAction({
    required String conflictId,
    required HealthSyncStatus status,
    required Future<void> Function(SyncConflictScope scope)? prepare,
    required HealthSyncRunner runner,
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
      final entity = result.resultFor(SyncEntityType.health);
      final nextStatus = result.isSuccessful
          ? HealthSyncStatus.succeeded
          : entity?.status == SyncEntityStatus.conflict
          ? HealthSyncStatus.conflict
          : HealthSyncStatus.failed;
      if (ref.mounted) {
        state = state.copyWith(
          status: nextStatus,
          lastResult: result,
          clearResolvingConflictId: true,
        );
      }
      if (result.isSuccessful) {
        await ref.read(healthViewRefresherProvider)();
      }
      return result;
    } catch (_) {
      await reloadConflictCount();
      if (ref.mounted) {
        state = state.copyWith(
          status: HealthSyncStatus.failed,
          errorMessage: '冲突处理失败，本地 Health 内容已保留',
          clearResolvingConflictId: true,
        );
      }
      rethrow;
    }
  }

  Future<void> reloadConflictCount() async {
    try {
      final scope = await ref.read(syncConflictScopeProvider.future);
      if (!ref.mounted) return;
      final count = scope == null
          ? 0
          : (await ref
                    .read(syncConflictRepositoryProvider)
                    .listActiveConflicts(scope))
                .where((item) => item.entityType == SyncEntityType.health)
                .length;
      if (!ref.mounted) return;
      state = state.copyWith(activeConflictCount: count);
      ref.invalidate(activeSyncConflictCountProvider);
      ref.invalidate(activeSyncConflictListProvider);
    } catch (_) {
      // Conflict count is auxiliary to the requested sync operation.
    }
  }

  Future<SyncConflictScope> _requireScope() async {
    final scope = await ref.read(syncConflictScopeProvider.future);
    if (scope == null) {
      throw const SyncException('请先登录当前 Endpoint 的云账号。');
    }
    return scope;
  }

  Future<bool> _hasAwaitingRemoteSnapshot() async {
    final scope = await ref.read(syncConflictScopeProvider.future);
    if (scope == null || !ref.mounted) return false;
    final records = await ref
        .read(syncConflictRepositoryProvider)
        .listActiveConflicts(scope);
    return records.any(
      (item) =>
          item.entityType == SyncEntityType.health &&
          item.resolutionStatus ==
              SyncConflictResolutionStatus.awaitingRemoteSnapshot,
    );
  }

  void _clearActive(Future<SyncRunResult> completed) {
    if (identical(_active, completed)) {
      _active = null;
      _activeOperation = null;
    }
  }
}
