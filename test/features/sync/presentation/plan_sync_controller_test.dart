import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
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
}

SyncRunResult _successResult() {
  return SyncRunResult(
    direction: SyncRunDirection.twoWay,
    phases: const [SyncRunPhase.completed],
    entityResults: const [
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

SyncRunResult _conflictResult() {
  return SyncRunResult(
    direction: SyncRunDirection.twoWay,
    phases: const [SyncRunPhase.apply, SyncRunPhase.failed],
    entityResults: const [
      SyncEntityResult(
        entityType: SyncEntityType.plan,
        status: SyncEntityStatus.conflict,
        message: 'Plan 冲突',
        conflictCount: 2,
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
