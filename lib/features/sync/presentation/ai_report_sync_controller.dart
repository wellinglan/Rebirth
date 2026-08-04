import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_report_history_controller.dart';
import 'package:rebirth/features/sync/data/sync_conflict_providers.dart';
import 'package:rebirth/features/sync/data/sync_providers.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

import 'ai_report_sync_view_state.dart';

final aiReportSyncControllerProvider =
    NotifierProvider<AiReportSyncController, AiReportSyncViewState>(
      AiReportSyncController.new,
    );

typedef AiReportSyncRunner = Future<SyncRunResult> Function();

final aiReportSyncRunnerProvider = Provider<AiReportSyncRunner>(
  (ref) =>
      () => ref
          .read(syncCoordinatorProvider)
          .run(
            direction: SyncRunDirection.twoWay,
            entityTypes: const [SyncEntityType.aiReport],
          ),
);
final aiReportConflictPullRunnerProvider = Provider<AiReportSyncRunner>(
  (ref) =>
      () => ref
          .read(syncCoordinatorProvider)
          .run(
            direction: SyncRunDirection.pull,
            entityTypes: const [SyncEntityType.aiReport],
            pullMode: SyncPullMode.preferRemoteConflictResolution,
          ),
);
final aiReportPushRunnerProvider = Provider<AiReportSyncRunner>(
  (ref) =>
      () => ref
          .read(syncCoordinatorProvider)
          .run(
            direction: SyncRunDirection.push,
            entityTypes: const [SyncEntityType.aiReport],
          ),
);

class AiReportSyncController extends Notifier<AiReportSyncViewState> {
  Future<SyncRunResult>? _active;

  @override
  AiReportSyncViewState build() => const AiReportSyncViewState();

  Future<SyncRunResult> syncAiReports() => _single(_sync);
  Future<SyncRunResult> retryConflictHydration(String id) => _single(
    () => _resolve(id, null, ref.read(aiReportConflictPullRunnerProvider)),
  );
  Future<SyncRunResult> adoptRemote(String id) => _single(
    () => _resolve(
      id,
      (scope) => ref
          .read(aiReportConflictResolutionServiceProvider)
          .requestAdoptRemote(scope: scope, conflictId: id),
      ref.read(aiReportConflictPullRunnerProvider),
    ),
  );
  Future<SyncRunResult> keepLocal(String id) => _single(
    () => _resolve(
      id,
      (scope) => ref
          .read(aiReportConflictResolutionServiceProvider)
          .requestKeepLocal(scope: scope, conflictId: id),
      ref.read(aiReportPushRunnerProvider),
    ),
  );

  Future<SyncRunResult> retryRequestedResolution(String id) async {
    final scope = await _scope();
    final item = await ref
        .read(syncConflictRepositoryProvider)
        .getConflict(scope, id);
    return switch (item.resolutionStatus) {
      SyncConflictResolutionStatus.adoptRemoteRequested =>
        retryConflictHydration(id),
      SyncConflictResolutionStatus.keepLocalRequested => _single(
        () => _resolve(id, null, ref.read(aiReportPushRunnerProvider)),
      ),
      _ => throw const SyncException('No retryable AI report conflict action.'),
    };
  }

  Future<SyncRunResult> _single(Future<SyncRunResult> Function() run) {
    if (_active != null) return _active!;
    final future = run();
    _active = future;
    future.whenComplete(() {
      if (identical(_active, future)) _active = null;
    });
    return future;
  }

  Future<SyncRunResult> _sync() async {
    state = state.copyWith(
      status: AiReportSyncStatus.syncing,
      clearError: true,
    );
    try {
      final result = await ref.read(aiReportSyncRunnerProvider)();
      await _finish(result);
      return result;
    } catch (_) {
      state = state.copyWith(
        status: AiReportSyncStatus.failed,
        errorMessage: 'AI report sync failed; local data was retained.',
      );
      rethrow;
    }
  }

  Future<SyncRunResult> _resolve(
    String id,
    Future<void> Function(SyncConflictScope scope)? prepare,
    AiReportSyncRunner runner,
  ) async {
    state = state.copyWith(
      status: AiReportSyncStatus.resolving,
      resolvingConflictId: id,
      clearError: true,
    );
    try {
      if (prepare != null) await prepare(await _scope());
      final result = await runner();
      ref.invalidate(syncConflictDetailsProvider(id));
      await _finish(result, clearResolving: true);
      return result;
    } catch (_) {
      await reloadConflictCount();
      state = state.copyWith(
        status: AiReportSyncStatus.failed,
        errorMessage:
            'AI report conflict action failed; local data was retained.',
        clearResolvingConflictId: true,
      );
      rethrow;
    }
  }

  Future<void> _finish(
    SyncRunResult result, {
    bool clearResolving = false,
  }) async {
    await reloadConflictCount();
    final entity = result.resultFor(SyncEntityType.aiReport);
    final status = result.isSuccessful
        ? AiReportSyncStatus.succeeded
        : entity?.status == SyncEntityStatus.conflict
        ? AiReportSyncStatus.conflict
        : AiReportSyncStatus.failed;
    state = state.copyWith(
      status: status,
      lastResult: result,
      clearResolvingConflictId: clearResolving,
    );
    if (result.isSuccessful) ref.invalidate(aiReportHistoryControllerProvider);
  }

  Future<void> reloadConflictCount() async {
    final scope = await ref.read(syncConflictScopeProvider.future);
    final records = scope == null
        ? const <SyncConflictRecord>[]
        : await ref
              .read(syncConflictRepositoryProvider)
              .listActiveConflicts(scope);
    state = state.copyWith(
      activeConflictCount: records
          .where((item) => item.entityType == SyncEntityType.aiReport)
          .length,
    );
    ref.invalidate(activeSyncConflictCountProvider);
    ref.invalidate(activeSyncConflictListProvider);
  }

  Future<SyncConflictScope> _scope() async {
    final value = await ref.read(syncConflictScopeProvider.future);
    if (value == null) {
      throw const SyncException('An active cloud account is required.');
    }
    return value;
  }
}
