import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/sync/application/sync_all_orchestrator.dart';
import 'package:rebirth/features/sync/application/sync_module_registry.dart';
import 'package:rebirth/features/sync/application/sync_module_runner.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/domain/sync_module.dart';

void main() {
  test(
    'sync all runs six modules sequentially in explicit product order',
    () async {
      final calls = <SyncModuleId>[];
      var active = 0;
      var maxActive = 0;
      final registry = createDefaultSyncModuleRegistry();
      final runners = [
        for (final descriptor in registry.orderedModules)
          CallbackSyncModuleRunner(
            descriptor: descriptor,
            onRun: () async {
              active += 1;
              maxActive = active > maxActive ? active : maxActive;
              calls.add(descriptor.moduleId);
              await Future<void>.delayed(Duration.zero);
              active -= 1;
              return _success(descriptor);
            },
            onRefresh: () async {},
          ),
      ];

      final result = await SyncAllOrchestrator(
        registry: registry,
        runners: runners,
        nowMilliseconds: _clock(),
      ).run();

      expect(calls, SyncModuleId.values);
      expect(maxActive, 1);
      expect(result.moduleResults, hasLength(6));
      expect(
        result.moduleResults.map((item) => item.status),
        everyElement(SyncModuleExecutionStatus.succeeded),
      );
    },
  );

  test('module conflict and exception preserve results and continue', () async {
    final registry = createDefaultSyncModuleRegistry();
    final calls = <SyncModuleId>[];
    final runners = [
      for (final descriptor in registry.orderedModules)
        CallbackSyncModuleRunner(
          descriptor: descriptor,
          onRun: () async {
            calls.add(descriptor.moduleId);
            if (descriptor.moduleId == SyncModuleId.plan) {
              return _conflict(descriptor);
            }
            if (descriptor.moduleId == SyncModuleId.today) {
              throw StateError('module failed');
            }
            return _success(descriptor);
          },
          onRefresh: () async {},
        ),
    ];

    final result = await SyncAllOrchestrator(
      registry: registry,
      runners: runners,
      nowMilliseconds: _clock(),
    ).run();

    expect(calls, SyncModuleId.values);
    expect(result.moduleResults[1].status, SyncModuleExecutionStatus.conflict);
    expect(result.moduleResults[2].status, SyncModuleExecutionStatus.failed);
    expect(
      result.moduleResults.last.status,
      SyncModuleExecutionStatus.succeeded,
    );
    expect(result.isPartialSuccess, isTrue);
  });

  test(
    'global precondition failure stops once and marks remaining skipped',
    () async {
      final registry = createDefaultSyncModuleRegistry();
      final calls = <SyncModuleId>[];
      final runners = [
        for (final descriptor in registry.orderedModules)
          CallbackSyncModuleRunner(
            descriptor: descriptor,
            onRun: () async {
              calls.add(descriptor.moduleId);
              return _globalFailure(descriptor);
            },
            onRefresh: () async {},
          ),
      ];

      final result = await SyncAllOrchestrator(
        registry: registry,
        runners: runners,
        nowMilliseconds: _clock(),
      ).run();

      expect(calls, const [SyncModuleId.profile]);
      expect(
        result.moduleResults.first.status,
        SyncModuleExecutionStatus.failed,
      );
      expect(
        result.moduleResults.skip(1).map((item) => item.status),
        everyElement(SyncModuleExecutionStatus.skipped),
      );
    },
  );
}

int Function() _clock() {
  var value = 100;
  return () => value++;
}

SyncRunResult _success(SyncModuleDescriptor descriptor) {
  return SyncRunResult(
    direction: SyncRunDirection.twoWay,
    phases: const [],
    entityResults: [
      for (final entity in descriptor.entityTypes)
        SyncEntityResult(
          entityType: entity,
          status: SyncEntityStatus.succeeded,
          message: 'ok',
          pushedCount: 1,
        ),
    ],
    startedAt: 1,
    completedAt: 2,
  );
}

SyncRunResult _conflict(SyncModuleDescriptor descriptor) {
  return SyncRunResult(
    direction: SyncRunDirection.twoWay,
    phases: const [],
    entityResults: [
      SyncEntityResult(
        entityType: descriptor.entityTypes.first,
        status: SyncEntityStatus.conflict,
        message: 'conflict',
        conflictCount: 1,
      ),
    ],
    startedAt: 1,
    completedAt: 2,
    failure: SyncFailure(
      reason: SyncFailureReason.conflict,
      phase: SyncRunPhase.apply,
      message: 'conflict',
      entityType: descriptor.entityTypes.first,
    ),
  );
}

SyncRunResult _globalFailure(SyncModuleDescriptor descriptor) {
  return SyncRunResult(
    direction: SyncRunDirection.twoWay,
    phases: const [SyncRunPhase.endpointCheck, SyncRunPhase.failed],
    entityResults: const [],
    startedAt: 1,
    completedAt: 2,
    failure: const SyncFailure(
      reason: SyncFailureReason.endpointUnavailable,
      phase: SyncRunPhase.endpointCheck,
      message: 'unavailable',
    ),
  );
}
