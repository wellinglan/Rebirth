import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

enum AiReportSyncStatus {
  idle,
  syncing,
  resolving,
  succeeded,
  partial,
  conflict,
  failed,
}

final class AiReportSyncViewState {
  const AiReportSyncViewState({
    this.status = AiReportSyncStatus.idle,
    this.lastResult,
    this.errorMessage,
    this.resolvingConflictId,
    this.activeConflictCount = 0,
    this.feedbackPushedCount = 0,
    this.feedbackPulledCount = 0,
    this.feedbackConflictCount = 0,
    this.feedbackDeferredCount = 0,
    this.feedbackErrorMessage,
  });

  final AiReportSyncStatus status;
  final SyncRunResult? lastResult;
  final String? errorMessage;
  final String? resolvingConflictId;
  final int activeConflictCount;
  final int feedbackPushedCount;
  final int feedbackPulledCount;
  final int feedbackConflictCount;
  final int feedbackDeferredCount;
  final String? feedbackErrorMessage;

  bool get isBusy =>
      status == AiReportSyncStatus.syncing ||
      status == AiReportSyncStatus.resolving;
  int get pushedCount =>
      lastResult?.resultFor(SyncEntityType.aiReport)?.pushedCount ?? 0;
  int get pulledCount =>
      lastResult?.resultFor(SyncEntityType.aiReport)?.pulledCount ?? 0;
  int get deletedCount =>
      lastResult?.resultFor(SyncEntityType.aiReport)?.deletedCount ?? 0;
  int get conflictCount =>
      lastResult?.resultFor(SyncEntityType.aiReport)?.conflictCount ?? 0;

  AiReportSyncViewState copyWith({
    AiReportSyncStatus? status,
    SyncRunResult? lastResult,
    String? errorMessage,
    bool clearError = false,
    String? resolvingConflictId,
    bool clearResolvingConflictId = false,
    int? activeConflictCount,
    int? feedbackPushedCount,
    int? feedbackPulledCount,
    int? feedbackConflictCount,
    int? feedbackDeferredCount,
    String? feedbackErrorMessage,
    bool clearFeedbackError = false,
  }) => AiReportSyncViewState(
    status: status ?? this.status,
    lastResult: lastResult ?? this.lastResult,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    resolvingConflictId: clearResolvingConflictId
        ? null
        : resolvingConflictId ?? this.resolvingConflictId,
    activeConflictCount: activeConflictCount ?? this.activeConflictCount,
    feedbackPushedCount: feedbackPushedCount ?? this.feedbackPushedCount,
    feedbackPulledCount: feedbackPulledCount ?? this.feedbackPulledCount,
    feedbackConflictCount: feedbackConflictCount ?? this.feedbackConflictCount,
    feedbackDeferredCount: feedbackDeferredCount ?? this.feedbackDeferredCount,
    feedbackErrorMessage: clearFeedbackError
        ? null
        : feedbackErrorMessage ?? this.feedbackErrorMessage,
  );
}
