import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/sync/application/sync_module_registry.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/domain/sync_module.dart';
import 'package:rebirth/features/sync/presentation/sync_center_controller.dart';
import 'package:rebirth/features/sync/presentation/sync_center_page.dart';
import 'package:rebirth/features/sync/presentation/sync_center_view_state.dart';

void main() {
  testWidgets('Sync Center shows five user modules and privacy-safe metrics', (
    tester,
  ) async {
    await _pump(tester, _state(), height: 2400);

    expect(find.text('同步中心'), findsOneWidget);
    expect(find.textContaining('尚未启用自动同步'), findsOneWidget);
    expect(find.byKey(const ValueKey('syncAllButton')), findsOneWidget);
    for (final module in const [
      'Profile',
      'Plan',
      'Today',
      'Journal',
      'Health',
    ]) {
      expect(find.text(module), findsOneWidget);
    }
    expect(find.text('Journal Prompt Configuration'), findsNothing);
    expect(find.textContaining('Health 包含敏感个人数据'), findsOneWidget);
    for (final label in const ['上传 3', '拉取 2', '删除 1', '冲突 0', '失败项 0']) {
      expect(find.text(label), findsWidgets);
    }
    for (final forbidden in const [
      'serverVersion',
      'cursor',
      'originDeviceId',
      'payload',
      'http://',
    ]) {
      expect(find.textContaining(forbidden), findsNothing);
    }
  });

  testWidgets(
    'running all shows live progress and disables every sync action',
    (tester) async {
      await _pump(
        tester,
        _state(
          isRunning: true,
          isSyncingAll: true,
          currentModule: SyncModuleId.today,
          completedModules: 2,
        ),
        height: 2400,
      );

      expect(find.textContaining('2 / 5'), findsOneWidget);
      expect(find.textContaining('正在同步 Today'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('syncAllButton')))
            .onPressed,
        isNull,
      );
      for (final id in SyncModuleId.values) {
        final button = tester.widget<FilledButton>(
          find.byKey(ValueKey('syncModuleButton-${id.stableId}')),
        );
        expect(button.onPressed, isNull);
      }
    },
  );

  for (final width in const [320.0, 360.0, 412.0, 720.0, 840.0, 1200.0]) {
    testWidgets('Sync Center has no overflow at ${width.toInt()}px', (
      tester,
    ) async {
      await _pump(tester, _state(), width: width);
      await tester.drag(find.byType(ListView), const Offset(0, -1600));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Sync Center remains usable at text scale 2', (tester) async {
    await _pump(tester, _state(), width: 320, textScale: 2);
    await tester.drag(find.byType(ListView), const Offset(0, -1800));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  SyncCenterViewState value, {
  double width = 900,
  double height = 900,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        syncCenterControllerProvider.overrideWith(
          () => _FakeSyncCenterController(value),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const SyncCenterPage(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

SyncCenterViewState _state({
  bool isRunning = false,
  bool isSyncingAll = false,
  SyncModuleId? currentModule,
  int completedModules = 0,
}) {
  final modules = createDefaultSyncModuleRegistry().orderedModules;
  return SyncCenterViewState(
    modules: modules,
    results: {
      for (final module in modules)
        module.moduleId: SyncModuleExecutionResult.fromRun(
          descriptor: module,
          run: SyncRunResult(
            direction: SyncRunDirection.twoWay,
            phases: const [],
            entityResults: [
              SyncEntityResult(
                entityType: module.entityTypes.first,
                status: SyncEntityStatus.succeeded,
                message: 'ok',
                pushedCount: 3,
                pulledCount: 2,
                deletedCount: 1,
              ),
              if (module.moduleId == SyncModuleId.journal)
                const SyncEntityResult(
                  entityType: SyncEntityType.journal,
                  status: SyncEntityStatus.noChanges,
                  message: 'none',
                ),
            ],
            startedAt: 1,
            completedAt: 2,
          ),
        ),
    },
    isRunning: isRunning,
    isSyncingAll: isSyncingAll,
    currentModule: currentModule,
    completedModules: completedModules,
  );
}

final class _FakeSyncCenterController extends SyncCenterController {
  _FakeSyncCenterController(this.value);
  final SyncCenterViewState value;

  @override
  Future<SyncCenterViewState> build() async => value;
}
