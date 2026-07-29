import '../domain/sync_module.dart';

final class SyncCenterViewState {
  SyncCenterViewState({
    required Iterable<SyncModuleDescriptor> modules,
    Map<SyncModuleId, SyncModuleExecutionResult>? results,
    Map<SyncModuleId, int>? conflictCounts,
    this.isRunning = false,
    this.isSyncingAll = false,
    this.currentModule,
    this.completedModules = 0,
    this.lastAllResult,
  }) : modules = List.unmodifiable(modules),
       results = Map.unmodifiable(results ?? const {}),
       conflictCounts = Map.unmodifiable(conflictCounts ?? const {});

  final List<SyncModuleDescriptor> modules;
  final Map<SyncModuleId, SyncModuleExecutionResult> results;
  final Map<SyncModuleId, int> conflictCounts;
  final bool isRunning;
  final bool isSyncingAll;
  final SyncModuleId? currentModule;
  final int completedModules;
  final SyncAllExecutionResult? lastAllResult;

  int get totalConflictCount =>
      conflictCounts.values.fold(0, (total, count) => total + count);

  String get overallStatusLabel {
    if (isRunning) return '正在同步';
    if (totalConflictCount > 0) return '需要处理';
    if (results.values.any(
      (result) =>
          result.status == SyncModuleExecutionStatus.failed ||
          result.status == SyncModuleExecutionStatus.partial,
    )) {
      return '最近同步未完全完成';
    }
    if (results.isNotEmpty) return '本次会话已同步';
    return '空闲';
  }

  SyncCenterViewState copyWith({
    Map<SyncModuleId, SyncModuleExecutionResult>? results,
    Map<SyncModuleId, int>? conflictCounts,
    bool? isRunning,
    bool? isSyncingAll,
    SyncModuleId? currentModule,
    bool clearCurrentModule = false,
    int? completedModules,
    SyncAllExecutionResult? lastAllResult,
  }) {
    return SyncCenterViewState(
      modules: modules,
      results: results ?? this.results,
      conflictCounts: conflictCounts ?? this.conflictCounts,
      isRunning: isRunning ?? this.isRunning,
      isSyncingAll: isSyncingAll ?? this.isSyncingAll,
      currentModule: clearCurrentModule
          ? null
          : currentModule ?? this.currentModule,
      completedModules: completedModules ?? this.completedModules,
      lastAllResult: lastAllResult ?? this.lastAllResult,
    );
  }
}
