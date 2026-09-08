import 'package:rebirth/features/sync/data/default_sync_merge_policies.dart';
import 'package:rebirth/features/sync/domain/conflict_reconciliation_service.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_adapter.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/domain/sync_record_baseline_repository.dart';

typedef ReconciliationScopeLoader = Future<SyncConflictScope?> Function();
typedef ReconciliationExecutionGuard =
    Future<bool> Function(SyncConflictScope expectedScope);
typedef ReconciliationSyncRunner =
    Future<SyncRunResult> Function({
      required SyncRunDirection direction,
      required Iterable<SyncEntityType> entityTypes,
      required SyncPullMode pullMode,
    });
typedef ReconciliationRetryPreparer =
    Future<void> Function({
      required SyncConflictScope scope,
      required String conflictId,
      required SyncConflictSnapshot expectedLocal,
      SyncEntityPayload? mergedPayload,
    });
typedef ReconciliationSnapshotLoader =
    Future<SyncConflictSnapshot?> Function({
      required SyncEntityType entityType,
      required String localUserId,
      required String recordId,
    });

final class SyncConflictReconciliationRunner {
  const SyncConflictReconciliationRunner({
    required this.syncRunner,
    required this.conflicts,
    required this.baselines,
    required this.policies,
    required this.adapters,
    required this.prepareLocalRetry,
    required this.scopeLoader,
    required this.executionGuard,
    required this.snapshotLoader,
    this.reconciliationService = const ConflictReconciliationService(),
  });

  static const int maximumOccRecalculations = 1;

  final ReconciliationSyncRunner syncRunner;
  final SyncConflictRepository conflicts;
  final SyncRecordBaselineRepository baselines;
  final SyncMergePolicyRegistry policies;
  final SyncEntityAdapterRegistry adapters;
  final ReconciliationRetryPreparer prepareLocalRetry;
  final ReconciliationScopeLoader scopeLoader;
  final ReconciliationExecutionGuard executionGuard;
  final ReconciliationSnapshotLoader snapshotLoader;
  final ConflictReconciliationService reconciliationService;

  Future<SyncRunResult> reconcile({
    required Iterable<SyncEntityType> entityTypes,
    required SyncRunResult initialResult,
  }) async {
    final selectedTypes = entityTypes.toSet();
    final scope = await scopeLoader();
    if (scope == null) return initialResult;

    final actionRuns = <SyncRunResult>[];
    final automaticCounts = <SyncEntityType, int>{};
    final activeAtStart = await conflicts.listActiveConflicts(scope);
    final externalManualCounts = <SyncEntityType, int>{};
    for (final entityType in selectedTypes) {
      final reported = initialResult.resultFor(entityType)?.conflictCount ?? 0;
      final tracked = activeAtStart
          .where((conflict) => conflict.entityType == entityType)
          .length;
      if (reported > tracked) {
        externalManualCounts[entityType] = reported - tracked;
      }
    }
    for (final original in activeAtStart) {
      if (!selectedTypes.contains(original.entityType)) continue;
      try {
        var conflict = original;
        if (!conflict.remoteSnapshotReady) {
          final hydration = await _pullForSnapshot(scope, conflict.entityType);
          actionRuns.add(hydration);
          conflict = await conflicts.getConflict(scope, conflict.id);
          if (!conflict.isActive || !conflict.remoteSnapshotReady) continue;
        }

        for (
          var attempt = 0;
          attempt <= maximumOccRecalculations;
          attempt += 1
        ) {
          if (!await _readyScope(scope)) return initialResult;
          final execution = await _decideAndExecute(scope, conflict);
          if (execution.run != null) actionRuns.add(execution.run!);
          if (execution.resolved) {
            automaticCounts.update(
              conflict.entityType,
              (value) => value + 1,
              ifAbsent: () => 1,
            );
            break;
          }
          if (!execution.retryableOcc || attempt == maximumOccRecalculations) {
            break;
          }
          final hydration = await _pullForSnapshot(scope, conflict.entityType);
          actionRuns.add(hydration);
          conflict = await conflicts.getConflict(scope, conflict.id);
          if (!conflict.isActive || !conflict.remoteSnapshotReady) break;
        }
      } on SyncConflictResolutionException {
        // The conflict remains active and available for explicit resolution.
      } on SyncConflictChangedException {
        // Local or remote state changed after the decision. Re-open it manually.
      }
    }

    if (!await _readyScope(scope)) return initialResult;
    final remaining = await conflicts.listActiveConflicts(scope);
    return _composeResult(
      selectedTypes: selectedTypes,
      initial: initialResult,
      actions: actionRuns,
      automaticCounts: automaticCounts,
      externalManualCounts: externalManualCounts,
      remaining: remaining,
    );
  }

  Future<bool> canAttemptAutomatically(
    SyncConflictScope scope,
    SyncConflictRecord conflict,
  ) async {
    if (!conflict.remoteSnapshotReady) return true;
    final decision = await _decision(scope, conflict);
    return decision?.isAutomatic ?? false;
  }

  Future<_ReconciliationExecution> _decideAndExecute(
    SyncConflictScope scope,
    SyncConflictRecord conflict,
  ) async {
    final local = await snapshotLoader(
      entityType: conflict.entityType,
      localUserId: scope.localUserId,
      recordId: conflict.recordId,
    );
    final decision = await _decision(scope, conflict, currentLocal: local);
    if (local == null ||
        decision == null ||
        decision.outcome == ConflictReconciliationOutcome.manualConflict) {
      return const _ReconciliationExecution();
    }
    if (!await _readyScope(scope)) {
      throw const SyncConflictResolutionException('同步会话或设备资格已变化，自动协调已停止。');
    }

    switch (decision.outcome) {
      case ConflictReconciliationOutcome.noChange:
      case ConflictReconciliationOutcome.adoptRemote:
        await conflicts.markAdoptRemoteRequested(scope, conflict.id);
        final run = await syncRunner(
          direction: SyncRunDirection.pull,
          entityTypes: [conflict.entityType],
          pullMode: SyncPullMode.preferRemoteConflictResolution,
        );
        return _resolutionResult(scope, conflict.id, run);
      case ConflictReconciliationOutcome.retryLocal:
      case ConflictReconciliationOutcome.mergeAndRetry:
        final mergedPayload = decision.mergedPayload == null
            ? null
            : _decodeMergedPayload(conflict, decision.mergedPayload!);
        await prepareLocalRetry(
          scope: scope,
          conflictId: conflict.id,
          expectedLocal: local,
          mergedPayload: mergedPayload,
        );
        final run = await syncRunner(
          direction: SyncRunDirection.push,
          entityTypes: [conflict.entityType],
          pullMode: SyncPullMode.incremental,
        );
        return _resolutionResult(scope, conflict.id, run);
      case ConflictReconciliationOutcome.manualConflict:
        return const _ReconciliationExecution();
    }
  }

  Future<ConflictReconciliationDecision?> _decision(
    SyncConflictScope scope,
    SyncConflictRecord conflict, {
    SyncConflictSnapshot? currentLocal,
  }) async {
    if (!conflict.isActive || !conflict.remoteSnapshotReady) return null;
    if (conflict.entityType != SyncEntityType.profile &&
        conflict.remoteRecordId != null &&
        conflict.remoteRecordId != conflict.recordId) {
      return const ConflictReconciliationDecision(
        outcome: ConflictReconciliationOutcome.manualConflict,
        reasonCode: 'record_identity_mismatch',
      );
    }
    final local =
        currentLocal ??
        await snapshotLoader(
          entityType: conflict.entityType,
          localUserId: scope.localUserId,
          recordId: conflict.recordId,
        );
    if (local == null) return null;
    final policy = policies.policyFor(conflict.entityType);
    final adapter = adapters.adapterFor(conflict.entityType);
    final baseline = await baselines.read(
      localUserId: scope.localUserId,
      entityType: conflict.entityType.wireName,
      recordId: conflict.recordId,
    );
    return reconciliationService.reconcile(
      policy: policy,
      baseline: baseline,
      local: _state(local, adapter),
      remote: _state(conflict.remoteSnapshot, adapter),
    );
  }

  ReconciliationRecordState _state(
    SyncConflictSnapshot snapshot,
    SyncEntityAdapter adapter,
  ) {
    return ReconciliationRecordState(
      exists: true,
      tombstone: snapshot.deletedAt != null,
      payload: snapshot.payload == null
          ? null
          : adapter.encodePayload(snapshot.payload!),
      serverVersion: snapshot.serverVersion,
    );
  }

  SyncEntityPayload _decodeMergedPayload(
    SyncConflictRecord conflict,
    Map<String, Object?> payload,
  ) {
    final adapter = adapters.adapterFor(conflict.entityType);
    final origin =
        conflict.localSnapshot.originDeviceId ??
        conflict.remoteSnapshot.originDeviceId;
    if (origin == null) {
      throw const SyncConflictResolutionException('协调快照缺少来源设备，已保留人工冲突。');
    }
    final decoded = adapter.decodeRemoteChange(
      recordId: conflict.remoteRecordId ?? conflict.recordId,
      payload: payload,
      updatedAt:
          conflict.localSnapshot.updatedAt ??
          conflict.remoteSnapshot.updatedAt ??
          0,
      deletedAt: null,
      originDeviceId: origin,
      serverVersion: conflict.remoteSnapshot.serverVersion!,
    );
    final result = decoded.payload;
    if (result == null) {
      throw const SyncConflictResolutionException('协调后的 payload 无效。');
    }
    return result;
  }

  Future<SyncRunResult> _pullForSnapshot(
    SyncConflictScope scope,
    SyncEntityType entityType,
  ) async {
    if (!await _readyScope(scope)) {
      return _scopeChangedResult(entityType);
    }
    return syncRunner(
      direction: SyncRunDirection.pull,
      entityTypes: [entityType],
      pullMode: SyncPullMode.preferRemoteConflictResolution,
    );
  }

  Future<_ReconciliationExecution> _resolutionResult(
    SyncConflictScope scope,
    String conflictId,
    SyncRunResult run,
  ) async {
    if (!await _readyScope(scope)) {
      return _ReconciliationExecution(run: run);
    }
    final refreshed = await conflicts.getConflict(scope, conflictId);
    if (!refreshed.isActive) {
      return _ReconciliationExecution(run: run, resolved: true);
    }
    final retryable =
        refreshed.remoteSnapshot.serverVersion != null &&
        (run.failure?.reason == SyncFailureReason.conflict ||
            run.resultFor(refreshed.entityType)?.status ==
                SyncEntityStatus.conflict);
    return _ReconciliationExecution(run: run, retryableOcc: retryable);
  }

  Future<bool> _sameScope(SyncConflictScope expected) async {
    final current = await scopeLoader();
    return current != null &&
        current.localUserId == expected.localUserId &&
        current.endpointKey == expected.endpointKey &&
        current.cloudUserId == expected.cloudUserId;
  }

  Future<bool> _readyScope(SyncConflictScope expected) async {
    return await _sameScope(expected) && await executionGuard(expected);
  }

  SyncRunResult _composeResult({
    required Set<SyncEntityType> selectedTypes,
    required SyncRunResult initial,
    required List<SyncRunResult> actions,
    required Map<SyncEntityType, int> automaticCounts,
    required Map<SyncEntityType, int> externalManualCounts,
    required List<SyncConflictRecord> remaining,
  }) {
    final results = <SyncEntityResult>[];
    for (final entityType in selectedTypes) {
      final all = <SyncEntityResult>[];
      final initialEntity = initial.resultFor(entityType);
      if (initialEntity != null) all.add(initialEntity);
      for (final action in actions) {
        final actionEntity = action.resultFor(entityType);
        if (actionEntity != null) all.add(actionEntity);
      }
      final automatic =
          (automaticCounts[entityType] ?? 0) +
          _sum(all, (item) => item.automaticallyReconciledCount);
      final manual =
          remaining
              .where((conflict) => conflict.entityType == entityType)
              .length +
          (externalManualCounts[entityType] ?? 0);
      final failed = all.any(
        (result) => result.status == SyncEntityStatus.failed,
      );
      final progressed =
          automatic > 0 ||
          all.any(
            (result) =>
                result.pushedCount > 0 ||
                result.pulledCount > 0 ||
                result.deletedCount > 0,
          );
      final status = manual > 0
          ? SyncEntityStatus.conflict
          : failed
          ? SyncEntityStatus.failed
          : progressed
          ? SyncEntityStatus.succeeded
          : all.isEmpty
          ? SyncEntityStatus.noChanges
          : all.last.status;
      results.add(
        SyncEntityResult(
          entityType: entityType,
          status: status,
          message: manual > 0
              ? '仍有 $manual 条需要人工处理'
              : automatic > 0
              ? '已自动协调 $automatic 条'
              : all.isEmpty
              ? '没有需要同步的更新'
              : all.last.message,
          pushedCount: _sum(all, (item) => item.pushedCount),
          pulledCount: _sum(all, (item) => item.pulledCount),
          deletedCount: _sum(all, (item) => item.deletedCount),
          ignoredCount: _sum(all, (item) => item.ignoredCount),
          conflictCount: manual,
          automaticallyReconciledCount: automatic,
          serverVersion: all
              .map((item) => item.serverVersion)
              .whereType<int>()
              .fold<int?>(
                null,
                (current, value) =>
                    current == null || value > current ? value : current,
              ),
        ),
      );
    }

    SyncFailure? actionFailure;
    for (final action in actions) {
      final candidate = action.failure;
      if (candidate != null && candidate.reason != SyncFailureReason.conflict) {
        actionFailure = candidate;
        break;
      }
    }
    final remainingCount = results.fold<int>(
      0,
      (total, result) => total + result.conflictCount,
    );
    final failure =
        actionFailure ??
        (remainingCount > 0
            ? const SyncFailure(
                reason: SyncFailureReason.conflict,
                phase: SyncRunPhase.apply,
                message: '部分数据仍需人工处理。',
              )
            : initial.failure?.reason == SyncFailureReason.conflict
            ? null
            : initial.failure);
    return SyncRunResult(
      direction: initial.direction,
      phases: [
        ...initial.phases,
        for (final action in actions) ...action.phases,
      ],
      entityResults: results,
      startedAt: initial.startedAt,
      completedAt: actions.isEmpty
          ? initial.completedAt
          : actions.last.completedAt,
      failure: failure,
    );
  }

  int _sum(
    Iterable<SyncEntityResult> values,
    int Function(SyncEntityResult value) select,
  ) => values.fold(0, (total, value) => total + select(value));

  SyncRunResult _scopeChangedResult(SyncEntityType entityType) {
    const message = '同步账号或 Endpoint 已变化，旧协调结果已丢弃。';
    return SyncRunResult(
      direction: SyncRunDirection.pull,
      phases: const [SyncRunPhase.failed],
      entityResults: [
        SyncEntityResult(
          entityType: entityType,
          status: SyncEntityStatus.failed,
          message: message,
        ),
      ],
      startedAt: 0,
      completedAt: 0,
      failure: const SyncFailure(
        reason: SyncFailureReason.accountScopeMismatch,
        phase: SyncRunPhase.accountScopeCheck,
        message: message,
      ),
    );
  }
}

final class _ReconciliationExecution {
  const _ReconciliationExecution({
    this.run,
    this.resolved = false,
    this.retryableOcc = false,
  });

  final SyncRunResult? run;
  final bool resolved;
  final bool retryableOcc;
}
