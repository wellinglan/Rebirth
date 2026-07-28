import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/sync/data/sync_conflict_providers.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/presentation/today_sync_controller.dart';
import 'package:rebirth/features/sync/presentation/today_sync_view_state.dart';

void main() {
  test('successful Today sync refreshes views and exposes counts', () async {
    var refreshCalls = 0;
    final container = ProviderContainer(
      overrides: [
        syncConflictScopeProvider.overrideWith((ref) async => null),
        todaySyncRunnerProvider.overrideWithValue(
          () async => _result(
            status: SyncEntityStatus.succeeded,
            pushed: 1,
            pulled: 2,
            deleted: 1,
          ),
        ),
        todayViewRefresherProvider.overrideWithValue(() async {
          refreshCalls += 1;
        }),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(todaySyncControllerProvider.notifier)
        .syncToday();
    final state = container.read(todaySyncControllerProvider);

    expect(result.isSuccessful, isTrue);
    expect(state.status, TodaySyncStatus.succeeded);
    expect(state.pushedCount, 1);
    expect(state.pulledCount, 2);
    expect(state.deletedCount, 1);
    expect(refreshCalls, 1);
  });

  test('overlapping Today sync calls reuse one operation', () async {
    final completer = Completer<SyncRunResult>();
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        todaySyncRunnerProvider.overrideWithValue(() {
          calls += 1;
          return completer.future;
        }),
        todayViewRefresherProvider.overrideWithValue(() async {}),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(todaySyncControllerProvider.notifier);
    final first = controller.syncToday();
    final second = controller.syncToday();

    expect(identical(first, second), isTrue);
    expect(calls, 1);
    expect(
      container.read(todaySyncControllerProvider).status,
      TodaySyncStatus.syncing,
    );

    completer.complete(_result(status: SyncEntityStatus.succeeded));
    await first;
    expect(
      container.read(todaySyncControllerProvider).status,
      TodaySyncStatus.succeeded,
    );
  });

  test(
    'structured conflict remains visible and does not refresh Today',
    () async {
      var refreshCalls = 0;
      final container = ProviderContainer(
        overrides: [
          syncConflictScopeProvider.overrideWith((ref) async => null),
          todaySyncRunnerProvider.overrideWithValue(
            () async =>
                _result(status: SyncEntityStatus.conflict, conflicts: 1),
          ),
          todayViewRefresherProvider.overrideWithValue(() async {
            refreshCalls += 1;
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(todaySyncControllerProvider.notifier).syncToday();
      final state = container.read(todaySyncControllerProvider);

      expect(state.status, TodaySyncStatus.conflict);
      expect(state.conflictCount, 1);
      expect(refreshCalls, 0);
    },
  );

  test('runner exception preserves a retryable failed state', () async {
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        todaySyncRunnerProvider.overrideWithValue(() async {
          calls += 1;
          if (calls == 1) throw StateError('offline');
          return _result(status: SyncEntityStatus.succeeded);
        }),
        todayViewRefresherProvider.overrideWithValue(() async {}),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(todaySyncControllerProvider.notifier);

    await expectLater(controller.syncToday(), throwsStateError);
    expect(
      container.read(todaySyncControllerProvider).status,
      TodaySyncStatus.failed,
    );

    await controller.syncToday();
    expect(calls, 2);
    expect(
      container.read(todaySyncControllerProvider).status,
      TodaySyncStatus.succeeded,
    );
  });
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
        entityType: SyncEntityType.today,
        status: status,
        message: status == SyncEntityStatus.succeeded
            ? 'Today synced'
            : 'Today conflict',
        pushedCount: pushed,
        pulledCount: pulled,
        deletedCount: deleted,
        conflictCount: conflicts,
      ),
    ],
    failure: status == SyncEntityStatus.succeeded
        ? null
        : SyncFailure(
            reason: SyncFailureReason.conflict,
            phase: SyncRunPhase.push,
            message: 'Today conflict',
          ),
    startedAt: 1,
    completedAt: 2,
  );
}
