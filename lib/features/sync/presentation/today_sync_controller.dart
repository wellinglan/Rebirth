import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/sync/data/sync_conflict_providers.dart';
import 'package:rebirth/features/sync/data/sync_providers.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
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

final todayViewRefresherProvider = Provider<TodayViewRefresher>((ref) {
  return () async {
    await ref.read(todayControllerProvider.notifier).reload();
    ref.invalidate(todayHistoryControllerProvider);
  };
});

class TodaySyncController extends Notifier<TodaySyncViewState> {
  Future<SyncRunResult>? _active;

  @override
  TodaySyncViewState build() => const TodaySyncViewState();

  Future<SyncRunResult> syncToday() {
    final active = _active;
    if (active != null) return active;
    final future = _runSync();
    _active = future;
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
        result = await ref.read(todayPullRunnerProvider)();
      }
      ref.invalidate(activeSyncConflictCountProvider);
      ref.invalidate(activeSyncConflictListProvider);
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
    if (identical(_active, completed)) _active = null;
  }
}
