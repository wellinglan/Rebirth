import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';

enum PlanSyncStatus { idle, syncing, succeeded, conflict, failed }

final class PlanSyncViewState {
  const PlanSyncViewState({
    this.status = PlanSyncStatus.idle,
    this.lastResult,
    this.errorMessage,
  });

  final PlanSyncStatus status;
  final SyncRunResult? lastResult;
  final String? errorMessage;

  bool get isBusy => status == PlanSyncStatus.syncing;
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
    PlanSyncStatus.succeeded =>
      '已同步：上传 $pushedCount，拉取 $pulledCount，删除 $deletedCount',
    PlanSyncStatus.conflict => '检测到 $conflictCount 个冲突，本地修改已保留',
    PlanSyncStatus.failed =>
      errorMessage ?? lastResult?.failure?.message ?? '同步失败',
  };
}
