import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/sync/application/sync_module_registry.dart';
import 'package:rebirth/features/sync/application/sync_module_runner.dart';
import 'package:rebirth/features/sync/data/sync_conflict_providers.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/domain/sync_module.dart';
import 'package:rebirth/features/sync/presentation/sync_center_controller.dart';
import 'package:rebirth/features/sync/presentation/sync_module_providers.dart';

void main() {
  test(
    'controller starts idle and rebuild does not retain transient running state',
    () async {
      final harness = _Harness();
      final container = harness.container();
      addTearDown(container.dispose);

      final initial = await container.read(syncCenterControllerProvider.future);
      expect(initial.isRunning, isFalse);
      expect(initial.results, isEmpty);

      container.invalidate(syncCenterControllerProvider);
      final rebuilt = await container.read(syncCenterControllerProvider.future);
      expect(rebuilt.isRunning, isFalse);
      expect(rebuilt.results, isEmpty);
    },
  );

  test(
    'repeated module action returns one Future and one runner invocation',
    () async {
      final gate = Completer<SyncRunResult>();
      final harness = _Harness(profileGate: gate);
      final container = harness.container();
      addTearDown(container.dispose);
      await container.read(syncCenterControllerProvider.future);
      final controller = container.read(syncCenterControllerProvider.notifier);

      final first = controller.syncModule(SyncModuleId.profile);
      final repeated = controller.syncModule(SyncModuleId.profile);
      await Future<void>.delayed(Duration.zero);

      expect(identical(first, repeated), isTrue);
      expect(harness.profileCalls, 1);
      expect(
        container.read(syncCenterControllerProvider).value!.isRunning,
        isTrue,
      );

      gate.complete(_run(SyncModuleId.profile));
      final result = await first;
      expect(result.status, SyncModuleExecutionStatus.succeeded);
      expect(
        container.read(syncCenterControllerProvider).value!.isRunning,
        isFalse,
      );
    },
  );

  test('refresh calls each registered module status reader', () async {
    final harness = _Harness();
    final container = harness.container();
    addTearDown(container.dispose);
    await container.read(syncCenterControllerProvider.future);

    await container.read(syncCenterControllerProvider.notifier).refresh();

    expect(harness.refreshCalls, 6);
  });
}

final class _Harness {
  _Harness({this.profileGate});

  final Completer<SyncRunResult>? profileGate;
  int profileCalls = 0;
  int refreshCalls = 0;

  ProviderContainer container() {
    return ProviderContainer(
      overrides: [
        activeSyncConflictListProvider.overrideWith((ref) async => const []),
        syncModuleRunnersProvider.overrideWith((ref) {
          final registry = ref.watch(syncModuleRegistryProvider);
          return [
            for (final descriptor in registry.orderedModules)
              CallbackSyncModuleRunner(
                descriptor: descriptor,
                onRun: () {
                  if (descriptor.moduleId == SyncModuleId.profile) {
                    profileCalls += 1;
                    final gate = profileGate;
                    if (gate != null) return gate.future;
                  }
                  return Future.value(_run(descriptor.moduleId));
                },
                onRefresh: () async {
                  refreshCalls += 1;
                },
              ),
          ];
        }),
      ],
    );
  }
}

SyncRunResult _run(SyncModuleId moduleId) {
  final registry = createDefaultSyncModuleRegistry();
  final entity = registry.descriptorFor(moduleId).entityTypes.first;
  return SyncRunResult(
    direction: SyncRunDirection.twoWay,
    phases: const [],
    entityResults: [
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
