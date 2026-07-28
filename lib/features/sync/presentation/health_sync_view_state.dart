import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

enum HealthSyncStatus {
  idle,
  syncing,
  hydratingConflict,
  adoptingRemote,
  keepingLocal,
  succeeded,
  conflict,
  failed,
}

final class HealthSyncViewState {
  const HealthSyncViewState({
    this.status = HealthSyncStatus.idle,
    this.lastResult,
    this.errorMessage,
    this.resolvingConflictId,
    this.activeConflictCount = 0,
  });

  final HealthSyncStatus status;
  final SyncRunResult? lastResult;
  final String? errorMessage;
  final String? resolvingConflictId;
  final int activeConflictCount;

  bool get isBusy =>
      status == HealthSyncStatus.syncing ||
      status == HealthSyncStatus.hydratingConflict ||
      status == HealthSyncStatus.adoptingRemote ||
      status == HealthSyncStatus.keepingLocal;

  int get pushedCount =>
      lastResult?.resultFor(SyncEntityType.health)?.pushedCount ?? 0;
  int get pulledCount =>
      lastResult?.resultFor(SyncEntityType.health)?.pulledCount ?? 0;
  int get deletedCount =>
      lastResult?.resultFor(SyncEntityType.health)?.deletedCount ?? 0;
  int get conflictCount =>
      lastResult?.resultFor(SyncEntityType.health)?.conflictCount ?? 0;

  String get statusLabel => switch (status) {
    HealthSyncStatus.idle => '可手动同步',
    HealthSyncStatus.syncing => '同步中...',
    HealthSyncStatus.hydratingConflict => '正在获取云端版本...',
    HealthSyncStatus.adoptingRemote => '正在采用云端版本...',
    HealthSyncStatus.keepingLocal => '正在上传本地版本...',
    HealthSyncStatus.succeeded =>
      '已同步：上传 $pushedCount，拉取 $pulledCount，删除 $deletedCount',
    HealthSyncStatus.conflict => '检测到 $conflictCount 个冲突，本地内容已保留',
    HealthSyncStatus.failed =>
      errorMessage ?? lastResult?.failure?.message ?? '同步失败',
  };

  String get lastSyncLabel {
    final completedAt = lastResult?.completedAt;
    if (completedAt == null) return '尚未同步';
    final date = DateTime.fromMillisecondsSinceEpoch(completedAt).toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  HealthSyncViewState copyWith({
    HealthSyncStatus? status,
    SyncRunResult? lastResult,
    String? errorMessage,
    bool clearError = false,
    String? resolvingConflictId,
    bool clearResolvingConflictId = false,
    int? activeConflictCount,
  }) {
    return HealthSyncViewState(
      status: status ?? this.status,
      lastResult: lastResult ?? this.lastResult,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      resolvingConflictId: clearResolvingConflictId
          ? null
          : resolvingConflictId ?? this.resolvingConflictId,
      activeConflictCount: activeConflictCount ?? this.activeConflictCount,
    );
  }
}
