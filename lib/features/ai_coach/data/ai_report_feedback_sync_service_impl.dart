import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback_remote_data_source.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback_repository.dart';
import 'package:rebirth/features/sync/domain/conflict_reconciliation_service.dart';
import 'package:rebirth/features/sync/domain/sync_record_baseline.dart';
import 'package:rebirth/features/sync/domain/sync_record_baseline_repository.dart';

final class AiReportFeedbackSyncServiceImpl
    implements AiReportFeedbackSyncService {
  const AiReportFeedbackSyncServiceImpl({
    required this.repository,
    required this.remoteDataSource,
    this.baselines,
    this.reconciliationService = const ConflictReconciliationService(),
  });

  final AiReportFeedbackRepository repository;
  final AiReportFeedbackRemoteDataSource remoteDataSource;
  final SyncRecordBaselineRepository? baselines;
  final ConflictReconciliationService reconciliationService;

  @override
  Future<AiReportFeedbackSyncSummary> synchronize() async {
    var pushed = 0;
    var pulled = 0;
    var conflicts = 0;
    var deferred = 0;
    var automaticallyReconciled = 0;
    final manualConflictIds = <String>{};
    for (final local in await repository.listPending()) {
      try {
        final result =
            local.syncStatus == AiReportFeedbackSyncStatus.pendingDelete
            ? await remoteDataSource.delete(local)
            : await remoteDataSource.upsert(local);
        if (result.outcome == AiReportFeedbackMutationOutcome.applied) {
          await repository.markSynced(
            id: local.id,
            serverVersion: result.remote.serverVersion,
            serverUpdatedAt: result.remote.updatedAt,
          );
          pushed += 1;
        } else {
          final resolution = await _reconcile(
            local: local,
            remote: result.remote,
          );
          pushed += resolution.pushed;
          pulled += resolution.pulled;
          deferred += resolution.deferred;
          automaticallyReconciled += resolution.automaticallyReconciled;
          if (resolution.manualConflict) manualConflictIds.add(local.id);
        }
      } on ApiException catch (error) {
        if (error.errorCode == 'report_not_synced' ||
            error.errorCode == 'feedback_not_found') {
          deferred += 1;
          continue;
        }
        rethrow;
      }
    }
    for (final remote in await remoteDataSource.listAll()) {
      final before = await repository.getForVersion(
        reportId: remote.reportId,
        reportVersion: remote.reportVersion,
      );
      await repository.applyRemote(remote);
      final after = await repository.getForVersion(
        reportId: remote.reportId,
        reportVersion: remote.reportVersion,
      );
      if (before?.serverVersion != after?.serverVersion &&
          after?.syncStatus != AiReportFeedbackSyncStatus.conflict) {
        pulled += 1;
      }
      if (after?.syncStatus == AiReportFeedbackSyncStatus.conflict) {
        if (before != null) {
          final resolution = await _reconcile(local: before, remote: remote);
          pushed += resolution.pushed;
          pulled += resolution.pulled;
          deferred += resolution.deferred;
          automaticallyReconciled += resolution.automaticallyReconciled;
          if (resolution.manualConflict) manualConflictIds.add(before.id);
        } else {
          manualConflictIds.add(after!.id);
        }
      }
    }
    for (final feedback in await repository.listAllForActiveAccount()) {
      if (feedback.syncStatus == AiReportFeedbackSyncStatus.conflict) {
        manualConflictIds.add(feedback.id);
      }
    }
    conflicts = manualConflictIds.length;
    return AiReportFeedbackSyncSummary(
      pushed: pushed,
      pulled: pulled,
      conflicts: conflicts,
      deferred: deferred,
      automaticallyReconciled: automaticallyReconciled,
    );
  }

  Future<_FeedbackReconciliationResult> _reconcile({
    required AiReportFeedback local,
    required AiReportFeedbackRemoteRecord remote,
  }) async {
    if (local.id != remote.id) {
      await repository.markConflict(id: local.id, remote: remote.snapshot);
      return const _FeedbackReconciliationResult(manualConflict: true);
    }

    final localDeleted = local.deletedAt != null;
    final remoteDeleted = remote.deletedAt != null;
    final localHash = _feedbackHash(local.helpfulness, local.reasons);
    final remoteHash = _feedbackHash(remote.helpfulness, remote.reasons);
    if ((localDeleted && remoteDeleted) ||
        (!localDeleted && !remoteDeleted && localHash == remoteHash)) {
      await repository.markSynced(
        id: local.id,
        serverVersion: remote.serverVersion,
        serverUpdatedAt: remote.updatedAt,
      );
      return const _FeedbackReconciliationResult(automaticallyReconciled: 1);
    }

    final baseline = await baselines?.read(
      localUserId: local.userId,
      entityType: SyncRecordBaselineEntity.aiReportFeedback,
      recordId: local.id,
    );
    if (!_trustedBaseline(baseline, local, remote)) {
      await repository.markConflict(id: local.id, remote: remote.snapshot);
      return const _FeedbackReconciliationResult(manualConflict: true);
    }
    final base = baseline!;
    final baseHash = base.groupHashes['feedback']!;

    if (localDeleted || remoteDeleted) {
      if (!base.baseExists || base.baseTombstone) {
        await repository.markConflict(id: local.id, remote: remote.snapshot);
        return const _FeedbackReconciliationResult(manualConflict: true);
      }
      if (localDeleted && !remoteDeleted && remoteHash == baseHash) {
        return _retryOnce(local: local, remote: remote);
      }
      if (remoteDeleted && !localDeleted && localHash == baseHash) {
        return _adoptRemote(local, remote);
      }
      await repository.markConflict(id: local.id, remote: remote.snapshot);
      return const _FeedbackReconciliationResult(manualConflict: true);
    }

    if (localHash == baseHash && remoteHash != baseHash) {
      return _adoptRemote(local, remote);
    }
    if (remoteHash == baseHash && localHash != baseHash) {
      return _retryOnce(local: local, remote: remote);
    }
    await repository.markConflict(id: local.id, remote: remote.snapshot);
    return const _FeedbackReconciliationResult(manualConflict: true);
  }

  Future<_FeedbackReconciliationResult> _adoptRemote(
    AiReportFeedback local,
    AiReportFeedbackRemoteRecord remote,
  ) async {
    await repository.markConflict(id: local.id, remote: remote.snapshot);
    await repository.adoptRemote(local.id);
    return const _FeedbackReconciliationResult(
      pulled: 1,
      automaticallyReconciled: 1,
    );
  }

  Future<_FeedbackReconciliationResult> _retryOnce({
    required AiReportFeedback local,
    required AiReportFeedbackRemoteRecord remote,
  }) async {
    await repository.markConflict(id: local.id, remote: remote.snapshot);
    await repository.keepLocal(local.id);
    final retry = await repository.getForVersion(
      reportId: local.reportId,
      reportVersion: local.reportVersion,
    );
    if (retry == null) {
      return const _FeedbackReconciliationResult(manualConflict: true);
    }
    try {
      final result =
          retry.syncStatus == AiReportFeedbackSyncStatus.pendingDelete
          ? await remoteDataSource.delete(retry)
          : await remoteDataSource.upsert(retry);
      if (result.outcome == AiReportFeedbackMutationOutcome.applied) {
        await repository.markSynced(
          id: retry.id,
          serverVersion: result.remote.serverVersion,
          serverUpdatedAt: result.remote.updatedAt,
        );
        return const _FeedbackReconciliationResult(
          pushed: 1,
          automaticallyReconciled: 1,
        );
      }
      await repository.markConflict(
        id: retry.id,
        remote: result.remote.snapshot,
      );
      return const _FeedbackReconciliationResult(manualConflict: true);
    } on ApiException catch (error) {
      if (error.errorCode == 'report_not_synced' ||
          error.errorCode == 'feedback_not_found') {
        return const _FeedbackReconciliationResult(deferred: 1);
      }
      rethrow;
    }
  }

  bool _trustedBaseline(
    SyncRecordBaseline? baseline,
    AiReportFeedback local,
    AiReportFeedbackRemoteRecord remote,
  ) {
    return baseline != null &&
        baseline.entityType == SyncRecordBaselineEntity.aiReportFeedback &&
        baseline.localUserId == local.userId &&
        baseline.recordId == local.id &&
        baseline.groupHashes.keys.length == 1 &&
        baseline.groupHashes.containsKey('feedback') &&
        baseline.baseServerVersion <= remote.serverVersion &&
        (local.serverVersion == null ||
            baseline.baseServerVersion <= local.serverVersion!);
  }

  String _feedbackHash(
    AiReportHelpfulness helpfulness,
    Iterable<AiReportFeedbackReason> reasons,
  ) {
    final codes = reasons.map((reason) => reason.code).toList()..sort();
    return reconciliationService.hashCanonicalValue({
      'helpfulness': helpfulness.databaseValue,
      'reason_codes': codes,
    });
  }
}

final class _FeedbackReconciliationResult {
  const _FeedbackReconciliationResult({
    this.pushed = 0,
    this.pulled = 0,
    this.deferred = 0,
    this.automaticallyReconciled = 0,
    this.manualConflict = false,
  });

  final int pushed;
  final int pulled;
  final int deferred;
  final int automaticallyReconciled;
  final bool manualConflict;
}
