import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/journal/presentation/journal_controller.dart';
import 'package:rebirth/features/journal/presentation/journal_today_controller.dart';
import 'package:rebirth/features/sync/data/sync_conflict_providers.dart';
import 'package:rebirth/features/sync/data/sync_providers.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

import 'journal_sync_view_state.dart';

final journalSyncControllerProvider =
    NotifierProvider<JournalSyncController, JournalSyncViewState>(
      JournalSyncController.new,
    );

typedef JournalSyncRunner = Future<SyncRunResult> Function();
typedef JournalViewRefresher = Future<void> Function();

final journalSyncRunnerProvider = Provider<JournalSyncRunner>((ref) {
  return () => ref
      .read(syncCoordinatorProvider)
      .run(
        direction: SyncRunDirection.twoWay,
        entityTypes: const [SyncEntityType.journal],
      );
});

final journalConflictPullRunnerProvider = Provider<JournalSyncRunner>((ref) {
  return () => ref
      .read(syncCoordinatorProvider)
      .run(
        direction: SyncRunDirection.pull,
        entityTypes: const [SyncEntityType.journal],
        pullMode: SyncPullMode.preferRemoteConflictResolution,
      );
});

final journalPushRunnerProvider = Provider<JournalSyncRunner>((ref) {
  return () => ref
      .read(syncCoordinatorProvider)
      .run(
        direction: SyncRunDirection.push,
        entityTypes: const [SyncEntityType.journal],
      );
});

final journalViewRefresherProvider = Provider<JournalViewRefresher>((ref) {
  return () async {
    await ref.read(journalTodayControllerProvider.notifier).reload();
    await ref.read(journalControllerProvider.notifier).reload();
  };
});

class JournalSyncController extends Notifier<JournalSyncViewState> {
  Future<SyncRunResult>? _active;
  String? _activeOperation;

  @override
  JournalSyncViewState build() => const JournalSyncViewState();

  Future<SyncRunResult> syncJournal() => _start('sync', _runSync);

  Future<SyncRunResult> retryConflictHydration(String conflictId) {
    return _start(
      'hydrate:$conflictId',
      () => _runConflictAction(
        conflictId: conflictId,
        status: JournalSyncStatus.hydratingConflict,
        prepare: null,
        runner: ref.read(journalConflictPullRunnerProvider),
      ),
    );
  }

  Future<SyncRunResult> adoptRemote(String conflictId) {
    return _start(
      'adopt:$conflictId',
      () => _runConflictAction(
        conflictId: conflictId,
        status: JournalSyncStatus.adoptingRemote,
        prepare: (scope) => ref
            .read(journalConflictResolutionServiceProvider)
            .requestAdoptRemote(scope: scope, conflictId: conflictId),
        runner: ref.read(journalConflictPullRunnerProvider),
      ),
    );
  }

  Future<SyncRunResult> keepLocal(String conflictId) {
    return _start(
      'keep:$conflictId',
      () => _runConflictAction(
        conflictId: conflictId,
        status: JournalSyncStatus.keepingLocal,
        prepare: (scope) => ref
            .read(journalConflictResolutionServiceProvider)
            .requestKeepLocal(scope: scope, conflictId: conflictId),
        runner: ref.read(journalPushRunnerProvider),
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
          status: JournalSyncStatus.keepingLocal,
          prepare: null,
          runner: ref.read(journalPushRunnerProvider),
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
    state = state.copyWith(status: JournalSyncStatus.syncing, clearError: true);
    try {
      var result = await ref.read(journalSyncRunnerProvider)();
      final entity = result.resultFor(SyncEntityType.journal);
      if (!result.isSuccessful &&
          entity?.status == SyncEntityStatus.conflict &&
          await _hasAwaitingRemoteSnapshot()) {
        if (ref.mounted) {
          state = state.copyWith(status: JournalSyncStatus.hydratingConflict);
        }
        result = await ref.read(journalConflictPullRunnerProvider)();
      }
      await reloadConflictCount();
      final finalEntity = result.resultFor(SyncEntityType.journal);
      final status = result.isSuccessful
          ? JournalSyncStatus.succeeded
          : finalEntity?.status == SyncEntityStatus.conflict
          ? JournalSyncStatus.conflict
          : JournalSyncStatus.failed;
      if (ref.mounted) {
        state = state.copyWith(status: status, lastResult: result);
      }
      if (result.isSuccessful) {
        await ref.read(journalViewRefresherProvider)();
      }
      return result;
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          status: JournalSyncStatus.failed,
          errorMessage: 'Journal 同步失败，本地数据未受影响',
        );
      }
      rethrow;
    }
  }

  Future<SyncRunResult> _runConflictAction({
    required String conflictId,
    required JournalSyncStatus status,
    required Future<void> Function(SyncConflictScope scope)? prepare,
    required JournalSyncRunner runner,
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
      final entity = result.resultFor(SyncEntityType.journal);
      final nextStatus = result.isSuccessful
          ? JournalSyncStatus.succeeded
          : entity?.status == SyncEntityStatus.conflict
          ? JournalSyncStatus.conflict
          : JournalSyncStatus.failed;
      if (ref.mounted) {
        state = state.copyWith(
          status: nextStatus,
          lastResult: result,
          clearResolvingConflictId: true,
        );
      }
      if (result.isSuccessful) {
        await ref.read(journalViewRefresherProvider)();
      }
      return result;
    } catch (_) {
      await reloadConflictCount();
      if (ref.mounted) {
        state = state.copyWith(
          status: JournalSyncStatus.failed,
          errorMessage: '冲突处理失败，本地 Journal 内容已保留',
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
                .where((item) => item.entityType == SyncEntityType.journal)
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
          item.entityType == SyncEntityType.journal &&
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
