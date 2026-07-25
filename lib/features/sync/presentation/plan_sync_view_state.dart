import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';

enum PlanSyncStatus {
  idle,
  syncing,
  hydratingConflict,
  adoptingRemote,
  keepingLocal,
  succeeded,
  conflict,
  failed,
}

final class PlanSyncViewState {
  const PlanSyncViewState({
    this.status = PlanSyncStatus.idle,
    this.lastResult,
    this.errorMessage,
    this.activeConflictCount = 0,
    this.resolvingConflictId,
  });

  final PlanSyncStatus status;
  final SyncRunResult? lastResult;
  final String? errorMessage;
  final int activeConflictCount;
  final String? resolvingConflictId;

  bool get isBusy =>
      status == PlanSyncStatus.syncing ||
      status == PlanSyncStatus.hydratingConflict ||
      status == PlanSyncStatus.adoptingRemote ||
      status == PlanSyncStatus.keepingLocal;
  int get pushedCount =>
      lastResult?.resultFor(SyncEntityType.plan)?.pushedCount ?? 0;
  int get pulledCount =>
      lastResult?.resultFor(SyncEntityType.plan)?.pulledCount ?? 0;
  int get deletedCount =>
      lastResult?.resultFor(SyncEntityType.plan)?.deletedCount ?? 0;
  int get conflictCount =>
      lastResult?.resultFor(SyncEntityType.plan)?.conflictCount ?? 0;

  String get statusLabel => switch (status) {
    PlanSyncStatus.idle => '可手动同步',
    PlanSyncStatus.syncing => '同步中...',
    PlanSyncStatus.hydratingConflict => '正在获取云端冲突版本...',
    PlanSyncStatus.adoptingRemote => '正在采用云端版本...',
    PlanSyncStatus.keepingLocal => '正在上传本地版本...',
    PlanSyncStatus.succeeded =>
      '已同步：上传 $pushedCount，拉取 $pulledCount，删除 $deletedCount',
    PlanSyncStatus.conflict => '检测到 $conflictCount 个冲突，本地修改已保留',
    PlanSyncStatus.failed =>
      errorMessage ?? lastResult?.failure?.message ?? '同步失败',
  };

  PlanSyncViewState copyWith({
    PlanSyncStatus? status,
    SyncRunResult? lastResult,
    String? errorMessage,
    bool clearError = false,
    int? activeConflictCount,
    String? resolvingConflictId,
    bool clearResolvingConflictId = false,
  }) {
    return PlanSyncViewState(
      status: status ?? this.status,
      lastResult: lastResult ?? this.lastResult,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      activeConflictCount: activeConflictCount ?? this.activeConflictCount,
      resolvingConflictId: clearResolvingConflictId
          ? null
          : resolvingConflictId ?? this.resolvingConflictId,
    );
  }
}
