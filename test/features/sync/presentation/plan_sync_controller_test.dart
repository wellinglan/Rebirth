import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/plan/domain/plan_conflict_resolution_service.dart';
import 'package:rebirth/features/sync/data/sync_conflict_providers.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/presentation/plan_sync_controller.dart';
import 'package:rebirth/features/sync/presentation/plan_sync_view_state.dart';

void main() {
  test('manual Plan sync exposes success counts and refreshes Plan', () async {
    var refreshes = 0;
    final container = ProviderContainer(
      overrides: [
        planSyncRunnerProvider.overrideWithValue(() async => _successResult()),
        planViewRefresherProvider.overrideWithValue(() async {
          refreshes += 1;
        }),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(planSyncControllerProvider.notifier)
        .syncPlan();
    final state = container.read(planSyncControllerProvider);

    expect(result.direction, SyncRunDirection.twoWay);
    expect(state.status, PlanSyncStatus.succeeded);
    expect(state.pushedCount, 2);
    expect(state.pulledCount, 3);
    expect(state.deletedCount, 1);
    expect(refreshes, 1);
  });

  test('rapid repeated Plan sync reuses the active future', () async {
    final completer = Completer<SyncRunResult>();
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        planSyncRunnerProvider.overrideWithValue(() {
          calls += 1;
          return completer.future;
        }),
        planViewRefresherProvider.overrideWithValue(() async {}),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(planSyncControllerProvider.notifier);

    final first = notifier.syncPlan();
    final second = notifier.syncPlan();

    expect(identical(first, second), isTrue);
    expect(calls, 1);
    expect(container.read(planSyncControllerProvider).isBusy, isTrue);
    completer.complete(_successResult());
    await first;
  });

  test(
    'conflict and syncInProgress are exposed without Plan refresh',
    () async {
      var refreshes = 0;
      final conflictContainer = ProviderContainer(
        overrides: [
          planSyncRunnerProvider.overrideWithValue(
            () async => _conflictResult(),
          ),
          planViewRefresherProvider.overrideWithValue(() async {
            refreshes += 1;
          }),
        ],
      );
      addTearDown(conflictContainer.dispose);

      await conflictContainer
          .read(planSyncControllerProvider.notifier)
          .syncPlan();
      final conflictState = conflictContainer.read(planSyncControllerProvider);

      expect(conflictState.status, PlanSyncStatus.conflict);
      expect(conflictState.conflictCount, 2);
      expect(refreshes, 0);

      final busyContainer = ProviderContainer(
        overrides: [
          planSyncRunnerProvider.overrideWithValue(
            () async => _failedResult(SyncFailureReason.syncInProgress),
          ),
          planViewRefresherProvider.overrideWithValue(() async {}),
        ],
      );
      addTearDown(busyContainer.dispose);
      await busyContainer.read(planSyncControllerProvider.notifier).syncPlan();
      expect(
        busyContainer.read(planSyncControllerProvider).status,
        PlanSyncStatus.failed,
      );
    },
  );

  test('disposing during a Plan sync does not update dead UI state', () async {
    final completer = Completer<SyncRunResult>();
    final container = ProviderContainer(
      overrides: [
        planSyncRunnerProvider.overrideWithValue(() => completer.future),
        planViewRefresherProvider.overrideWithValue(() async {}),
      ],
    );
    final future = container
        .read(planSyncControllerProvider.notifier)
        .syncPlan();

    container.dispose();
    completer.complete(_successResult());

    await expectLater(future, completes);
  });

  test(
    'unexpected runner failure leaves an explicit retryable state',
    () async {
      final container = ProviderContainer(
        overrides: [
          planSyncRunnerProvider.overrideWithValue(
            () async => throw StateError('network failed'),
          ),
          planViewRefresherProvider.overrideWithValue(() async {}),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(planSyncControllerProvider.notifier).syncPlan(),
        throwsStateError,
      );

      final state = container.read(planSyncControllerProvider);
      expect(state.status, PlanSyncStatus.failed);
      expect(state.statusLabel, contains('本地数据未受影响'));
      expect(state.isBusy, isFalse);
    },
  );

  test('push conflict triggers one controlled pull hydration', () async {
    final repository = _FakeConflictRepository(_awaitingConflict());
    var pullCalls = 0;
    var refreshes = 0;
    final container = _conflictContainer(
      repository: repository,
      syncRunner: () async => _conflictResult(count: 1),
      pullRunner: () async {
        pullCalls += 1;
        repository.record = _record(
          status: SyncConflictResolutionStatus.unresolved,
        );
        return _successResult(direction: SyncRunDirection.pull);
      },
      refresher: () async => refreshes += 1,
    );
    addTearDown(container.dispose);

    await container.read(planSyncControllerProvider.notifier).syncPlan();

    expect(pullCalls, 1);
    expect(
      container.read(planSyncControllerProvider).status,
      PlanSyncStatus.succeeded,
    );
    expect(refreshes, 1);
  });

  test('hydration failure keeps an explicit retryable failed state', () async {
    final repository = _FakeConflictRepository(_awaitingConflict());
    final container = _conflictContainer(
      repository: repository,
      syncRunner: () async => _conflictResult(count: 1),
      pullRunner: () async => throw StateError('offline'),
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(planSyncControllerProvider.notifier).syncPlan(),
      throwsStateError,
    );

    expect(
      repository.record.resolutionStatus,
      SyncConflictResolutionStatus.awaitingRemoteSnapshot,
    );
    expect(
      container.read(planSyncControllerProvider).status,
      PlanSyncStatus.failed,
    );
  });

  test('adopt and keep requests run before their network operation', () async {
    final repository = _FakeConflictRepository(_record());
    final service = _FakeResolutionService(repository);
    final operations = <String>[];
    final container = _conflictContainer(
      repository: repository,
      service: service,
      pullRunner: () async {
        operations.add('pull');
        expect(
          repository.record.resolutionStatus,
          SyncConflictResolutionStatus.adoptRemoteRequested,
        );
        repository.record = _record(
          status: SyncConflictResolutionStatus.resolvedAdoptRemote,
          resolvedAt: 20,
        );
        return _successResult(direction: SyncRunDirection.pull);
      },
      pushRunner: () async {
        operations.add('push');
        expect(
          repository.record.resolutionStatus,
          SyncConflictResolutionStatus.keepLocalRequested,
        );
        repository.record = _record(
          status: SyncConflictResolutionStatus.resolvedKeepLocal,
          resolvedAt: 30,
        );
        return _successResult(direction: SyncRunDirection.push);
      },
    );
    addTearDown(container.dispose);
    final notifier = container.read(planSyncControllerProvider.notifier);

    await notifier.adoptRemote(_conflictId);
    repository.record = _record();
    await notifier.keepLocal(_conflictId);

    expect(service.operations, ['adopt', 'keep']);
    expect(operations, ['pull', 'push']);
  });

  test('requested resolution survives network failure and can retry', () async {
    final repository = _FakeConflictRepository(_record());
    final service = _FakeResolutionService(repository);
    var fail = true;
    final container = _conflictContainer(
      repository: repository,
      service: service,
      pushRunner: () async {
        if (fail) throw StateError('offline');
        repository.record = _record(
          status: SyncConflictResolutionStatus.resolvedKeepLocal,
          resolvedAt: 30,
        );
        return _successResult(direction: SyncRunDirection.push);
      },
    );
    addTearDown(container.dispose);
    final notifier = container.read(planSyncControllerProvider.notifier);

    await expectLater(notifier.keepLocal(_conflictId), throwsStateError);
    expect(
      repository.record.resolutionStatus,
      SyncConflictResolutionStatus.keepLocalRequested,
    );

    fail = false;
    await notifier.retryRequestedResolution(_conflictId);
    expect(
      repository.record.resolutionStatus,
      SyncConflictResolutionStatus.resolvedKeepLocal,
    );
  });

  test(
    'different conflict operation is rejected while sync is active',
    () async {
      final gate = Completer<SyncRunResult>();
      final repository = _FakeConflictRepository(_record());
      final container = _conflictContainer(
        repository: repository,
        syncRunner: () => gate.future,
      );
      addTearDown(container.dispose);
      final notifier = container.read(planSyncControllerProvider.notifier);

      final active = notifier.syncPlan();
      expect(
        () => notifier.adoptRemote(_conflictId),
        throwsA(isA<SyncException>()),
      );
      gate.complete(_successResult());
      await active;
    },
  );

  test('resolution requires a matching signed-in conflict scope', () async {
    final container = ProviderContainer(
      overrides: [
        syncConflictScopeProvider.overrideWith((ref) async => null),
        planPullRunnerProvider.overrideWithValue(
          () async => _successResult(direction: SyncRunDirection.pull),
        ),
        planViewRefresherProvider.overrideWithValue(() async {}),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(planSyncControllerProvider.notifier)
          .adoptRemote(_conflictId),
      throwsA(isA<SyncException>()),
    );
    expect(
      container.read(planSyncControllerProvider).status,
      PlanSyncStatus.failed,
    );
  });
}

SyncRunResult _successResult({
  SyncRunDirection direction = SyncRunDirection.twoWay,
}) {
  return SyncRunResult(
    direction: direction,
    phases: const [SyncRunPhase.completed],
    entityResults: [
      SyncEntityResult(
        entityType: SyncEntityType.plan,
        status: SyncEntityStatus.succeeded,
        message: 'Plan 已更新',
        pushedCount: 2,
        pulledCount: 3,
        deletedCount: 1,
      ),
    ],
    startedAt: 1,
    completedAt: 2,
  );
}

SyncRunResult _conflictResult({int count = 2}) {
  return SyncRunResult(
    direction: SyncRunDirection.twoWay,
    phases: const [SyncRunPhase.apply, SyncRunPhase.failed],
    entityResults: [
      SyncEntityResult(
        entityType: SyncEntityType.plan,
        status: SyncEntityStatus.conflict,
        message: 'Plan 冲突',
        conflictCount: count,
      ),
    ],
    startedAt: 1,
    completedAt: 2,
    failure: const SyncFailure(
      reason: SyncFailureReason.conflict,
      phase: SyncRunPhase.apply,
      message: 'Plan 冲突',
      entityType: SyncEntityType.plan,
    ),
  );
}

const _conflictId = '00000000-0000-4000-8000-000000000061';
const _recordId = '00000000-0000-4000-8000-000000000062';
const _scope = SyncConflictScope(
  localUserId: '00000000-0000-4000-8000-000000000063',
  endpointKey: 'http://server-a:8000',
  cloudUserId: 'cloud-a',
);

ProviderContainer _conflictContainer({
  required _FakeConflictRepository repository,
  PlanConflictResolutionService? service,
  PlanSyncRunner? syncRunner,
  PlanSyncRunner? pullRunner,
  PlanSyncRunner? pushRunner,
  PlanViewRefresher? refresher,
}) {
  return ProviderContainer(
    overrides: [
      syncConflictScopeProvider.overrideWith((ref) async => _scope),
      syncConflictRepositoryProvider.overrideWithValue(repository),
      planConflictResolutionServiceProvider.overrideWithValue(
        service ?? _FakeResolutionService(repository),
      ),
      planSyncRunnerProvider.overrideWithValue(
        syncRunner ?? () async => _successResult(),
      ),
      planPullRunnerProvider.overrideWithValue(
        pullRunner ??
            () async => _successResult(direction: SyncRunDirection.pull),
      ),
      planPushRunnerProvider.overrideWithValue(
        pushRunner ??
            () async => _successResult(direction: SyncRunDirection.push),
      ),
      planViewRefresherProvider.overrideWithValue(refresher ?? () async {}),
    ],
  );
}

SyncConflictRecord _awaitingConflict() {
  return _record(
    status: SyncConflictResolutionStatus.awaitingRemoteSnapshot,
    operation: SyncConflictOperation.unknownPendingPull,
  );
}

SyncConflictRecord _record({
  SyncConflictResolutionStatus status = SyncConflictResolutionStatus.unresolved,
  SyncConflictOperation operation = SyncConflictOperation.upsert,
  int? resolvedAt,
}) {
  return SyncConflictRecord(
    id: _conflictId,
    scope: _scope,
    entityType: SyncEntityType.plan,
    recordId: _recordId,
    localSnapshot: const SyncConflictSnapshot(
      payload: null,
      updatedAt: 1,
      deletedAt: null,
      serverVersion: 1,
      originDeviceId: null,
    ),
    remoteSnapshot: const SyncConflictSnapshot(
      payload: null,
      updatedAt: 2,
      deletedAt: null,
      serverVersion: 2,
      originDeviceId: null,
    ),
    remoteOperation: operation,
    detectedAt: 10,
    lastSeenAt: 10,
    resolutionStatus: status,
    resolvedAt: resolvedAt,
  );
}

final class _FakeResolutionService implements PlanConflictResolutionService {
  _FakeResolutionService(this.repository);

  final _FakeConflictRepository repository;
  final List<String> operations = [];

  @override
  Future<void> requestAdoptRemote({
    required SyncConflictScope scope,
    required String conflictId,
  }) async {
    operations.add('adopt');
    repository.record = _record(
      status: SyncConflictResolutionStatus.adoptRemoteRequested,
    );
  }

  @override
  Future<void> requestKeepLocal({
    required SyncConflictScope scope,
    required String conflictId,
  }) async {
    operations.add('keep');
    repository.record = _record(
      status: SyncConflictResolutionStatus.keepLocalRequested,
    );
  }
}

final class _FakeConflictRepository implements SyncConflictRepository {
  _FakeConflictRepository(this.record);

  SyncConflictRecord record;

  @override
  Future<SyncConflictRecord> getConflict(
    SyncConflictScope scope,
    String id,
  ) async => record;

  @override
  Future<List<SyncConflictRecord>> listActiveConflicts(
    SyncConflictScope scope,
  ) async => record.isActive ? [record] : const [];

  @override
  Stream<int> watchActiveConflictCount(SyncConflictScope scope) =>
      Stream.value(record.isActive ? 1 : 0);

  @override
  Future<SyncConflictRecord?> findActiveConflict({
    required SyncConflictScope scope,
    required SyncEntityType entityType,
    required String recordId,
  }) async => record.isActive ? record : null;

  @override
  Future<SyncConflictRecord> upsertDetectedConflict(
    SyncConflictDetection detection,
  ) async => record;

  @override
  Future<SyncConflictRecord> hydrateRemoteSnapshot({
    required SyncConflictScope scope,
    required SyncEntityType entityType,
    required String recordId,
    required SyncConflictOperation operation,
    required SyncConflictSnapshot remoteSnapshot,
    required int seenAt,
  }) async => record;

  @override
  Future<void> markAdoptRemoteRequested(
    SyncConflictScope scope,
    String id,
  ) async {}

  @override
  Future<void> markKeepLocalRequested(
    SyncConflictScope scope,
    String id,
  ) async {}

  @override
  Future<void> markResolvedAdoptRemote(
    SyncConflictScope scope,
    String id, {
    required int resolvedAt,
  }) async {}

  @override
  Future<void> markResolvedKeepLocal(
    SyncConflictScope scope,
    String id, {
    required int resolvedAt,
  }) async {}

  @override
  Future<void> markSuperseded(
    SyncConflictScope scope,
    String id, {
    required int resolvedAt,
  }) async {}
}

SyncRunResult _failedResult(SyncFailureReason reason) {
  return SyncRunResult(
    direction: SyncRunDirection.twoWay,
    phases: const [SyncRunPhase.failed],
    entityResults: const [
      SyncEntityResult(
        entityType: SyncEntityType.plan,
        status: SyncEntityStatus.failed,
        message: '已有同步任务',
      ),
    ],
    startedAt: 1,
    completedAt: 2,
    failure: SyncFailure(
      reason: reason,
      phase: SyncRunPhase.failed,
      message: '已有同步任务',
      entityType: SyncEntityType.plan,
    ),
  );
}
