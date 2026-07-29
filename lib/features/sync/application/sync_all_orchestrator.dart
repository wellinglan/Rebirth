import 'sync_module_registry.dart';
import 'sync_module_runner.dart';
import '../domain/sync_module.dart';

typedef SyncModuleProgressCallback =
    void Function(
      SyncModuleId currentModule,
      int completedModules,
      List<SyncModuleExecutionResult> results,
    );

final class SyncAllOrchestrator {
  SyncAllOrchestrator({
    required this.registry,
    required Iterable<SyncModuleRunner> runners,
    required this.nowMilliseconds,
  }) : _runners = {
         for (final runner in runners) runner.descriptor.moduleId: runner,
       };

  final SyncModuleRegistry registry;
  final Map<SyncModuleId, SyncModuleRunner> _runners;
  final int Function() nowMilliseconds;

  Future<SyncAllExecutionResult> run({
    SyncModuleProgressCallback? onProgress,
  }) async {
    final startedAt = nowMilliseconds();
    final results = <SyncModuleExecutionResult>[];
    var stopForGlobalFailure = false;

    for (final descriptor in registry.orderedModules) {
      if (stopForGlobalFailure) {
        results.add(
          SyncModuleExecutionResult.skipped(
            moduleId: descriptor.moduleId,
            timestamp: nowMilliseconds(),
            message: '因账号或连接条件未满足而未执行',
          ),
        );
        continue;
      }
      onProgress?.call(
        descriptor.moduleId,
        results.length,
        List.unmodifiable(results),
      );
      final runner = _runners[descriptor.moduleId];
      if (runner == null) {
        final timestamp = nowMilliseconds();
        results.add(
          SyncModuleExecutionResult(
            moduleId: descriptor.moduleId,
            status: SyncModuleExecutionStatus.failed,
            startedAt: timestamp,
            completedAt: timestamp,
            entityResults: const [],
            userFacingMessage: '该模块暂时无法同步',
          ),
        );
        continue;
      }
      try {
        final runResult = await runner.runManualSync();
        final moduleResult = SyncModuleExecutionResult.fromRun(
          descriptor: descriptor,
          run: runResult,
        );
        results.add(moduleResult);
        stopForGlobalFailure = moduleResult.isGlobalFailure;
      } catch (_) {
        final timestamp = nowMilliseconds();
        results.add(
          SyncModuleExecutionResult(
            moduleId: descriptor.moduleId,
            status: SyncModuleExecutionStatus.failed,
            startedAt: timestamp,
            completedAt: timestamp,
            entityResults: const [],
            userFacingMessage: '同步失败，本地数据未受影响',
          ),
        );
      }
    }

    return SyncAllExecutionResult(
      moduleResults: results,
      startedAt: startedAt,
      completedAt: nowMilliseconds(),
    );
  }
}
