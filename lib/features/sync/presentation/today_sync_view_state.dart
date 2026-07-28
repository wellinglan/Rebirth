import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

enum TodaySyncStatus {
  idle,
  syncing,
  hydratingConflict,
  adoptingRemote,
  keepingLocal,
  succeeded,
  conflict,
  failed,
}

final class TodaySyncViewState {
  const TodaySyncViewState({
    this.status = TodaySyncStatus.idle,
    this.lastResult,
    this.errorMessage,
    this.resolvingConflictId,
    this.activeConflictCount = 0,
  });

  final TodaySyncStatus status;
  final SyncRunResult? lastResult;
  final String? errorMessage;
  final String? resolvingConflictId;
  final int activeConflictCount;

  bool get isBusy =>
      status == TodaySyncStatus.syncing ||
      status == TodaySyncStatus.hydratingConflict ||
      status == TodaySyncStatus.adoptingRemote ||
      status == TodaySyncStatus.keepingLocal;

  int get pushedCount =>
      lastResult?.resultFor(SyncEntityType.today)?.pushedCount ?? 0;
  int get pulledCount =>
      lastResult?.resultFor(SyncEntityType.today)?.pulledCount ?? 0;
  int get deletedCount =>
      lastResult?.resultFor(SyncEntityType.today)?.deletedCount ?? 0;
  int get conflictCount =>
      lastResult?.resultFor(SyncEntityType.today)?.conflictCount ?? 0;

  String get statusLabel => switch (status) {
    TodaySyncStatus.idle => '可手动同步',
    TodaySyncStatus.syncing => '同步中...',
    TodaySyncStatus.hydratingConflict => '正在获取云端版本...',
    TodaySyncStatus.adoptingRemote => '正在采用云端版本...',
    TodaySyncStatus.keepingLocal => '正在上传本地版本...',
    TodaySyncStatus.succeeded =>
      '已同步：上传 $pushedCount，拉取 $pulledCount，删除 $deletedCount',
    TodaySyncStatus.conflict => '检测到 $conflictCount 个冲突，本地内容已保留',
    TodaySyncStatus.failed =>
      errorMessage ?? lastResult?.failure?.message ?? '同步失败',
  };

  TodaySyncViewState copyWith({
    TodaySyncStatus? status,
    SyncRunResult? lastResult,
    String? errorMessage,
    bool clearError = false,
    String? resolvingConflictId,
    bool clearResolvingConflictId = false,
    int? activeConflictCount,
  }) {
    return TodaySyncViewState(
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
