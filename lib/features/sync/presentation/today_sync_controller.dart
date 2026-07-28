import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/sync/data/sync_conflict_providers.dart';
import 'package:rebirth/features/sync/data/sync_providers.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/today/presentation/today_controller.dart';
import 'package:rebirth/features/today/presentation/today_history_controller.dart';

import 'today_sync_view_state.dart';

final todaySyncControllerProvider =
    NotifierProvider<TodaySyncController, TodaySyncViewState>(
      TodaySyncController.new,
    );

typedef TodaySyncRunner = Future<SyncRunResult> Function();
typedef TodayViewRefresher = Future<void> Function();

final todaySyncRunnerProvider = Provider<TodaySyncRunner>((ref) {
  return () => ref
      .read(syncCoordinatorProvider)
      .run(
        direction: SyncRunDirection.twoWay,
        entityTypes: const [SyncEntityType.today],
      );
});

final todayPullRunnerProvider = Provider<TodaySyncRunner>((ref) {
  return () => ref
      .read(syncCoordinatorProvider)
      .run(
        direction: SyncRunDirection.pull,
        entityTypes: const [SyncEntityType.today],
      );
});

final todayConflictPullRunnerProvider = Provider<TodaySyncRunner>((ref) {
  return () => ref
      .read(syncCoordinatorProvider)
      .run(
        direction: SyncRunDirection.pull,
        entityTypes: const [SyncEntityType.today],
        pullMode: SyncPullMode.preferRemoteConflictResolution,
      );
});

final todayPushRunnerProvider = Provider<TodaySyncRunner>((ref) {
  return () => ref
      .read(syncCoordinatorProvider)
      .run(
        direction: SyncRunDirection.push,
        entityTypes: const [SyncEntityType.today],
      );
});

final todayViewRefresherProvider = Provider<TodayViewRefresher>((ref) {
  return () async {
    await ref.read(todayControllerProvider.notifier).reload();
    ref.invalidate(todayHistoryControllerProvider);
  };
});

class TodaySyncController extends Notifier<TodaySyncViewState> {
  Future<SyncRunResult>? _active;
  String? _activeOperation;

  @override
  TodaySyncViewState build() => const TodaySyncViewState();

  Future<SyncRunResult> syncToday() {
    return _start('sync', _runSync);
  }

  Future<SyncRunResult> retryConflictHydration(String conflictId) {
    return _start(
      'hydrate:$conflictId',
      () => _runConflictAction(
        conflictId: conflictId,
        status: TodaySyncStatus.hydratingConflict,
        prepare: null,
        runner: ref.read(todayConflictPullRunnerProvider),
      ),
    );
  }

  Future<SyncRunResult> adoptRemote(String conflictId) {
    return _start(
      'adopt:$conflictId',
      () => _runConflictAction(
        conflictId: conflictId,
        status: TodaySyncStatus.adoptingRemote,
        prepare: (scope) => ref
            .read(todayConflictResolutionServiceProvider)
            .requestAdoptRemote(scope: scope, conflictId: conflictId),
        runner: ref.read(todayConflictPullRunnerProvider),
      ),
    );
  }

  Future<SyncRunResult> keepLocal(String conflictId) {
    return _start(
      'keep:$conflictId',
      () => _runConflictAction(
        conflictId: conflictId,
        status: TodaySyncStatus.keepingLocal,
        prepare: (scope) => ref
            .read(todayConflictResolutionServiceProvider)
            .requestKeepLocal(scope: scope, conflictId: conflictId),
        runner: ref.read(todayPushRunnerProvider),
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
          status: TodaySyncStatus.keepingLocal,
          prepare: null,
          runner: ref.read(todayPushRunnerProvider),
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
    state = state.copyWith(status: TodaySyncStatus.syncing, clearError: true);
    try {
      var result = await ref.read(todaySyncRunnerProvider)();
      final entity = result.resultFor(SyncEntityType.today);
      if (!result.isSuccessful &&
          entity?.status == SyncEntityStatus.conflict &&
          await _hasAwaitingRemoteSnapshot()) {
        if (ref.mounted) {
          state = state.copyWith(status: TodaySyncStatus.hydratingConflict);
        }
        result = await ref.read(todayConflictPullRunnerProvider)();
      }
      await reloadConflictCount();
      final finalEntity = result.resultFor(SyncEntityType.today);
      final status = result.isSuccessful
          ? TodaySyncStatus.succeeded
          : finalEntity?.status == SyncEntityStatus.conflict
          ? TodaySyncStatus.conflict
          : TodaySyncStatus.failed;
      if (ref.mounted) {
        state = state.copyWith(status: status, lastResult: result);
      }
      if (result.isSuccessful) {
        await ref.read(todayViewRefresherProvider)();
      }
      return result;
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          status: TodaySyncStatus.failed,
          errorMessage: 'Today 同步失败，本地数据未受影响',
        );
      }
      rethrow;
    }
  }

  Future<SyncRunResult> _runConflictAction({
    required String conflictId,
    required TodaySyncStatus status,
    required Future<void> Function(SyncConflictScope scope)? prepare,
    required TodaySyncRunner runner,
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
      final entity = result.resultFor(SyncEntityType.today);
      final status = result.isSuccessful
          ? TodaySyncStatus.succeeded
          : entity?.status == SyncEntityStatus.conflict
          ? TodaySyncStatus.conflict
          : TodaySyncStatus.failed;
      if (ref.mounted) {
        state = state.copyWith(
          status: status,
          lastResult: result,
          clearResolvingConflictId: true,
        );
      }
      if (result.isSuccessful) {
        await ref.read(todayViewRefresherProvider)();
      }
      return result;
    } catch (_) {
      await reloadConflictCount();
      if (ref.mounted) {
        state = state.copyWith(
          status: TodaySyncStatus.failed,
          errorMessage: '冲突处理失败，本地 Today 内容已保留',
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
                .where((item) => item.entityType == SyncEntityType.today)
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
          item.entityType == SyncEntityType.today &&
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
