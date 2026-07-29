import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';

import '../application/sync_module_runner.dart';
import '../data/sync_conflict_providers.dart';
import '../domain/sync_conflict_record.dart';
import '../domain/sync_exception.dart';
import '../domain/sync_module.dart';
import 'sync_center_view_state.dart';
import 'sync_module_providers.dart';

final syncCenterControllerProvider =
    AsyncNotifierProvider<SyncCenterController, SyncCenterViewState>(
      SyncCenterController.new,
    );

class SyncCenterController extends AsyncNotifier<SyncCenterViewState> {
  Future<SyncModuleExecutionResult>? _activeModuleRun;
  SyncModuleId? _activeModuleId;
  Future<SyncAllExecutionResult>? _activeAllRun;

  @override
  Future<SyncCenterViewState> build() async {
    final registry = ref.watch(syncModuleRegistryProvider);
    final conflicts = await ref.read(activeSyncConflictListProvider.future);
    return SyncCenterViewState(
      modules: registry.orderedModules,
      conflictCounts: _countConflicts(conflicts),
    );
  }

  Future<void> refresh() async {
    final current = state.value;
    if (current?.isRunning == true) return;
    state = const AsyncLoading();
    for (final runner in ref.read(syncModuleRunnersProvider)) {
      try {
        await runner.refreshStatus();
      } catch (_) {
        // A module status failure must not block the remaining status refresh.
      }
    }
    ref.invalidate(activeSyncConflictListProvider);
    state = await AsyncValue.guard(build);
  }

  Future<SyncModuleExecutionResult> syncModule(SyncModuleId moduleId) {
    final activeModule = _activeModuleRun;
    if (activeModule != null) {
      if (_activeModuleId == moduleId) return activeModule;
      throw const SyncException('已有同步任务正在进行。');
    }
    if (_activeAllRun != null) {
      throw const SyncException('正在同步全部模块，请稍候。');
    }
    final future = _runModule(moduleId);
    _activeModuleId = moduleId;
    _activeModuleRun = future;
    future.then<void>(
      (_) => _clearModule(future),
      onError: (Object _, StackTrace _) => _clearModule(future),
    );
    return future;
  }

  Future<SyncAllExecutionResult> syncAll() {
    final active = _activeAllRun;
    if (active != null) return active;
    if (_activeModuleRun != null) {
      throw const SyncException('已有模块正在同步，请稍候。');
    }
    final future = _runAll();
    _activeAllRun = future;
    future.then<void>(
      (_) => _clearAll(future),
      onError: (Object _, StackTrace _) => _clearAll(future),
    );
    return future;
  }

  Future<SyncModuleExecutionResult> _runModule(SyncModuleId moduleId) async {
    final current = _requireState();
    _publish(
      current.copyWith(
        isRunning: true,
        isSyncingAll: false,
        currentModule: moduleId,
        completedModules: 0,
      ),
    );
    final runner = _runnerFor(moduleId);
    try {
      final run = await runner.runManualSync();
      final result = SyncModuleExecutionResult.fromRun(
        descriptor: runner.descriptor,
        run: run,
      );
      final results = {..._requireState().results, moduleId: result};
      await _refreshConflicts();
      _publish(
        _requireState().copyWith(
          results: results,
          isRunning: false,
          clearCurrentModule: true,
          completedModules: 1,
        ),
      );
      return result;
    } catch (_) {
      final timestamp = ref
          .read(dateTimeServiceProvider)
          .currentSnapshot()
          .utcMilliseconds;
      final result = SyncModuleExecutionResult(
        moduleId: moduleId,
        status: SyncModuleExecutionStatus.failed,
        startedAt: timestamp,
        completedAt: timestamp,
        entityResults: const [],
        userFacingMessage: '同步失败，本地数据未受影响',
      );
      _publish(
        _requireState().copyWith(
          results: {..._requireState().results, moduleId: result},
          isRunning: false,
          clearCurrentModule: true,
        ),
      );
      rethrow;
    }
  }

  Future<SyncAllExecutionResult> _runAll() async {
    final current = _requireState();
    final queued = <SyncModuleId, SyncModuleExecutionResult>{
      for (final module in current.modules)
        module.moduleId: SyncModuleExecutionResult(
          moduleId: module.moduleId,
          status: SyncModuleExecutionStatus.queued,
          startedAt: 0,
          completedAt: 0,
          entityResults: const [],
          userFacingMessage: '等待执行',
        ),
    };
    _publish(
      current.copyWith(
        results: queued,
        isRunning: true,
        isSyncingAll: true,
        completedModules: 0,
        clearCurrentModule: true,
      ),
    );

    final result = await ref
        .read(syncAllOrchestratorProvider)
        .run(onProgress: _onAllProgress);
    await _refreshConflicts();
    _publish(
      _requireState().copyWith(
        results: {for (final item in result.moduleResults) item.moduleId: item},
        isRunning: false,
        isSyncingAll: false,
        clearCurrentModule: true,
        completedModules: result.moduleResults.length,
        lastAllResult: result,
      ),
    );
    return result;
  }

  void _onAllProgress(
    SyncModuleId currentModule,
    int completedModules,
    List<SyncModuleExecutionResult> completedResults,
  ) {
    if (!ref.mounted || state.value == null) return;
    final results = {..._requireState().results};
    for (final result in completedResults) {
      results[result.moduleId] = result;
    }
    final queued = results[currentModule];
    if (queued != null) {
      results[currentModule] = SyncModuleExecutionResult(
        moduleId: currentModule,
        status: SyncModuleExecutionStatus.running,
        startedAt: queued.startedAt,
        completedAt: queued.completedAt,
        entityResults: const [],
        userFacingMessage: '正在同步',
      );
    }
    _publish(
      _requireState().copyWith(
        results: results,
        currentModule: currentModule,
        completedModules: completedModules,
      ),
    );
  }

  Future<void> _refreshConflicts() async {
    ref.invalidate(activeSyncConflictListProvider);
    ref.invalidate(activeSyncConflictCountProvider);
    try {
      final conflicts = await ref.read(activeSyncConflictListProvider.future);
      if (ref.mounted && state.value != null) {
        _publish(
          _requireState().copyWith(conflictCounts: _countConflicts(conflicts)),
        );
      }
    } catch (_) {
      // Conflict counts are auxiliary to the requested manual sync.
    }
  }

  SyncModuleRunner _runnerFor(SyncModuleId id) {
    return ref
        .read(syncModuleRunnersProvider)
        .firstWhere((runner) => runner.descriptor.moduleId == id);
  }

  Map<SyncModuleId, int> _countConflicts(
    Iterable<SyncConflictRecord> conflicts,
  ) {
    final registry = ref.read(syncModuleRegistryProvider);
    final counts = <SyncModuleId, int>{};
    for (final conflict in conflicts) {
      final moduleId = registry.moduleForEntity(conflict.entityType);
      if (moduleId != null) {
        counts.update(moduleId, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }

  SyncCenterViewState _requireState() {
    final value = state.value;
    if (value == null) throw const SyncException('同步中心尚未准备完成。');
    return value;
  }

  void _publish(SyncCenterViewState value) {
    if (ref.mounted) state = AsyncData(value);
  }

  void _clearModule(Future<SyncModuleExecutionResult> completed) {
    if (identical(_activeModuleRun, completed)) {
      _activeModuleRun = null;
      _activeModuleId = null;
    }
  }

  void _clearAll(Future<SyncAllExecutionResult> completed) {
    if (identical(_activeAllRun, completed)) {
      _activeAllRun = null;
    }
  }
}
