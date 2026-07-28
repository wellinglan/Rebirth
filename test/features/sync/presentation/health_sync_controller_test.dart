import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/health/domain/health_conflict_resolution_service.dart';
import 'package:rebirth/features/sync/data/sync_conflict_providers.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/presentation/health_sync_controller.dart';
import 'package:rebirth/features/sync/presentation/health_sync_view_state.dart';

void main() {
  test('successful Health sync refreshes views and exposes counts', () async {
    var refreshCalls = 0;
    final container = ProviderContainer(
      overrides: [
        syncConflictScopeProvider.overrideWith((ref) async => null),
        healthSyncRunnerProvider.overrideWithValue(
          () async => _result(
            status: SyncEntityStatus.succeeded,
            pushed: 1,
            pulled: 2,
            deleted: 1,
          ),
        ),
        healthViewRefresherProvider.overrideWithValue(() async {
          refreshCalls += 1;
        }),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(healthSyncControllerProvider.notifier)
        .syncHealth();
    final state = container.read(healthSyncControllerProvider);

    expect(result.isSuccessful, isTrue);
    expect(state.status, HealthSyncStatus.succeeded);
    expect(state.pushedCount, 1);
    expect(state.pulledCount, 2);
    expect(state.deletedCount, 1);
    expect(refreshCalls, 1);
  });

  test('overlapping Health sync calls reuse one operation', () async {
    final completer = Completer<SyncRunResult>();
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        healthSyncRunnerProvider.overrideWithValue(() {
          calls += 1;
          return completer.future;
        }),
        healthViewRefresherProvider.overrideWithValue(() async {}),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(healthSyncControllerProvider.notifier);
    final first = controller.syncHealth();
    final second = controller.syncHealth();

    expect(identical(first, second), isTrue);
    expect(calls, 1);
    expect(
      container.read(healthSyncControllerProvider).status,
      HealthSyncStatus.syncing,
    );

    completer.complete(_result(status: SyncEntityStatus.succeeded));
    await first;
    expect(
      container.read(healthSyncControllerProvider).status,
      HealthSyncStatus.succeeded,
    );
  });

  test('conflict remains visible and does not refresh Health views', () async {
    var refreshCalls = 0;
    final container = ProviderContainer(
      overrides: [
        syncConflictScopeProvider.overrideWith((ref) async => null),
        healthSyncRunnerProvider.overrideWithValue(
          () async => _result(status: SyncEntityStatus.conflict, conflicts: 1),
        ),
        healthConflictPullRunnerProvider.overrideWithValue(
          () async => _result(status: SyncEntityStatus.conflict, conflicts: 1),
        ),
        healthViewRefresherProvider.overrideWithValue(() async {
          refreshCalls += 1;
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(healthSyncControllerProvider.notifier).syncHealth();
    final state = container.read(healthSyncControllerProvider);

    expect(state.status, HealthSyncStatus.conflict);
    expect(state.conflictCount, 1);
    expect(refreshCalls, 0);
  });

  test('adopt and keep local use explicit pull and push runners', () async {
    final operations = <String>[];
    final container = ProviderContainer(
      overrides: [
        syncConflictScopeProvider.overrideWith((ref) async => _scope),
        syncConflictRepositoryProvider.overrideWithValue(
          _FakeConflictRepository(),
        ),
        healthConflictResolutionServiceProvider.overrideWithValue(
          _FakeHealthConflictService(operations),
        ),
        healthConflictPullRunnerProvider.overrideWithValue(() async {
          operations.add('pull');
          return _result(status: SyncEntityStatus.succeeded);
        }),
        healthPushRunnerProvider.overrideWithValue(() async {
          operations.add('push');
          return _result(status: SyncEntityStatus.succeeded);
        }),
        healthViewRefresherProvider.overrideWithValue(() async {
          operations.add('refresh');
        }),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(healthSyncControllerProvider.notifier);

    await controller.adoptRemote('conflict');
    await controller.keepLocal('conflict');

    expect(operations, ['adopt', 'pull', 'refresh', 'keep', 'push', 'refresh']);
  });
}

const _scope = SyncConflictScope(
  localUserId: 'local-user',
  endpointKey: 'http://server-a:8000',
  cloudUserId: 'cloud-user',
);

final class _FakeHealthConflictService
    implements HealthConflictResolutionService {
  _FakeHealthConflictService(this.operations);

  final List<String> operations;

  @override
  Future<void> requestAdoptRemote({
    required SyncConflictScope scope,
    required String conflictId,
  }) async {
    operations.add('adopt');
  }

  @override
  Future<void> requestKeepLocal({
    required SyncConflictScope scope,
    required String conflictId,
  }) async {
    operations.add('keep');
  }
}

final class _FakeConflictRepository extends Fake
    implements SyncConflictRepository {
  @override
  Future<List<SyncConflictRecord>> listActiveConflicts(
    SyncConflictScope scope,
  ) async => const [];
}

SyncRunResult _result({
  required SyncEntityStatus status,
  int pushed = 0,
  int pulled = 0,
  int deleted = 0,
  int conflicts = 0,
}) {
  return SyncRunResult(
    direction: SyncRunDirection.twoWay,
    phases: const [SyncRunPhase.completed],
    entityResults: [
      SyncEntityResult(
        entityType: SyncEntityType.health,
        status: status,
        message: status == SyncEntityStatus.succeeded
            ? 'Health synced'
            : 'Health conflict',
        pushedCount: pushed,
        pulledCount: pulled,
        deletedCount: deleted,
        conflictCount: conflicts,
      ),
    ],
    failure: status == SyncEntityStatus.succeeded
        ? null
        : const SyncFailure(
            reason: SyncFailureReason.conflict,
            phase: SyncRunPhase.push,
            message: 'Health conflict',
          ),
    startedAt: 1,
    completedAt: 2,
  );
}
