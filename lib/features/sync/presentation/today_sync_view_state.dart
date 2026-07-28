import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

enum TodaySyncStatus { idle, syncing, succeeded, conflict, failed }

final class TodaySyncViewState {
  const TodaySyncViewState({
    this.status = TodaySyncStatus.idle,
    this.lastResult,
    this.errorMessage,
  });

  final TodaySyncStatus status;
  final SyncRunResult? lastResult;
  final String? errorMessage;

  bool get isBusy => status == TodaySyncStatus.syncing;

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
  }) {
    return TodaySyncViewState(
      status: status ?? this.status,
      lastResult: lastResult ?? this.lastResult,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
