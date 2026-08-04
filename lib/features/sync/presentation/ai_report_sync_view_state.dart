import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

enum AiReportSyncStatus {
  idle,
  syncing,
  resolving,
  succeeded,
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
  });

  final AiReportSyncStatus status;
  final SyncRunResult? lastResult;
  final String? errorMessage;
  final String? resolvingConflictId;
  final int activeConflictCount;

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
  }) => AiReportSyncViewState(
    status: status ?? this.status,
    lastResult: lastResult ?? this.lastResult,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    resolvingConflictId: clearResolvingConflictId
        ? null
        : resolvingConflictId ?? this.resolvingConflictId,
    activeConflictCount: activeConflictCount ?? this.activeConflictCount,
  );
}
