import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/domain/sync_module.dart';

void main() {
  test('module result aggregates all entity counters', () {
    final result = SyncModuleExecutionResult.fromRun(
      descriptor: _journal,
      run: _run([
        const SyncEntityResult(
          entityType: SyncEntityType.journalPromptConfiguration,
          status: SyncEntityStatus.succeeded,
          message: 'ok',
          pushedCount: 1,
          pulledCount: 2,
          deletedCount: 3,
          ignoredCount: 4,
        ),
        const SyncEntityResult(
          entityType: SyncEntityType.journal,
          status: SyncEntityStatus.succeeded,
          message: 'ok',
          pushedCount: 5,
          pulledCount: 6,
          deletedCount: 7,
          ignoredCount: 8,
        ),
      ]),
    );

    expect(result.status, SyncModuleExecutionStatus.succeeded);
    expect(result.pushedCount, 6);
    expect(result.pulledCount, 8);
    expect(result.deletedCount, 10);
    expect(result.ignoredCount, 12);
    expect(result.conflictCount, 0);
    expect(result.failedEntityCount, 0);
  });

  test(
    'module result distinguishes no changes conflict partial and failed',
    () {
      expect(
        _result(const [
          SyncEntityResult(
            entityType: SyncEntityType.journalPromptConfiguration,
            status: SyncEntityStatus.noChanges,
            message: 'none',
          ),
          SyncEntityResult(
            entityType: SyncEntityType.journal,
            status: SyncEntityStatus.noChanges,
            message: 'none',
          ),
        ]).status,
        SyncModuleExecutionStatus.noChanges,
      );
      expect(
        _result(const [
          SyncEntityResult(
            entityType: SyncEntityType.journal,
            status: SyncEntityStatus.conflict,
            message: 'conflict',
            conflictCount: 1,
          ),
        ]).status,
        SyncModuleExecutionStatus.conflict,
      );
      final partial = _result(const [
        SyncEntityResult(
          entityType: SyncEntityType.journalPromptConfiguration,
          status: SyncEntityStatus.succeeded,
          message: 'ok',
          pushedCount: 1,
        ),
        SyncEntityResult(
          entityType: SyncEntityType.journal,
          status: SyncEntityStatus.failed,
          message: 'failed',
        ),
      ]);
      expect(partial.status, SyncModuleExecutionStatus.partial);
      expect(partial.failedEntityCount, 1);
      expect(
        _result(const [
          SyncEntityResult(
            entityType: SyncEntityType.journal,
            status: SyncEntityStatus.failed,
            message: 'failed',
          ),
        ]).status,
        SyncModuleExecutionStatus.failed,
      );
    },
  );

  test('skipped result has no fabricated entity or record failures', () {
    final result = SyncModuleExecutionResult.skipped(
      moduleId: SyncModuleId.health,
      timestamp: 10,
      message: 'not run',
    );

    expect(result.status, SyncModuleExecutionStatus.skipped);
    expect(result.entityResults, isEmpty);
    expect(result.failedEntityCount, 0);
  });
}

final _journal = SyncModuleDescriptor(
  moduleId: SyncModuleId.journal,
  displayName: 'Journal',
  description: 'Journal',
  displayOrder: 40,
  entityTypes: const [
    SyncEntityType.journalPromptConfiguration,
    SyncEntityType.journal,
  ],
  sensitivity: SyncModuleSensitivity.sensitive,
);

SyncModuleExecutionResult _result(List<SyncEntityResult> results) {
  return SyncModuleExecutionResult.fromRun(
    descriptor: _journal,
    run: _run(results),
  );
}

SyncRunResult _run(List<SyncEntityResult> results) {
  return SyncRunResult(
    direction: SyncRunDirection.twoWay,
    phases: const [],
    entityResults: results,
    startedAt: 1,
    completedAt: 2,
  );
}
