import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

enum JournalSyncStatus {
  idle,
  syncing,
  hydratingConflict,
  adoptingRemote,
  keepingLocal,
  succeeded,
  conflict,
  failed,
}

final class JournalSyncViewState {
  const JournalSyncViewState({
    this.status = JournalSyncStatus.idle,
    this.lastResult,
    this.errorMessage,
    this.resolvingConflictId,
    this.activeConflictCount = 0,
  });

  final JournalSyncStatus status;
  final SyncRunResult? lastResult;
  final String? errorMessage;
  final String? resolvingConflictId;
  final int activeConflictCount;

  bool get isBusy =>
      status == JournalSyncStatus.syncing ||
      status == JournalSyncStatus.hydratingConflict ||
      status == JournalSyncStatus.adoptingRemote ||
      status == JournalSyncStatus.keepingLocal;

  int get pushedCount =>
      lastResult?.resultFor(SyncEntityType.journal)?.pushedCount ?? 0;
  int get pulledCount =>
      lastResult?.resultFor(SyncEntityType.journal)?.pulledCount ?? 0;
  int get deletedCount =>
      lastResult?.resultFor(SyncEntityType.journal)?.deletedCount ?? 0;
  int get conflictCount =>
      lastResult?.resultFor(SyncEntityType.journal)?.conflictCount ?? 0;

  String get statusLabel => switch (status) {
    JournalSyncStatus.idle => '可手动同步',
    JournalSyncStatus.syncing => '同步中...',
    JournalSyncStatus.hydratingConflict => '正在获取云端版本...',
    JournalSyncStatus.adoptingRemote => '正在采用云端版本...',
    JournalSyncStatus.keepingLocal => '正在上传本地版本...',
    JournalSyncStatus.succeeded =>
      '已同步：上传 $pushedCount，拉取 $pulledCount，删除 $deletedCount',
    JournalSyncStatus.conflict => '检测到 $conflictCount 个冲突，本地内容已保留',
    JournalSyncStatus.failed =>
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

  JournalSyncViewState copyWith({
    JournalSyncStatus? status,
    SyncRunResult? lastResult,
    String? errorMessage,
    bool clearError = false,
    String? resolvingConflictId,
    bool clearResolvingConflictId = false,
    int? activeConflictCount,
  }) {
    return JournalSyncViewState(
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
