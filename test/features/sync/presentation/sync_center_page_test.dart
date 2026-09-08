import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/sync/application/foreground_auto_sync_state.dart';
import 'package:rebirth/features/sync/application/sync_module_registry.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/domain/sync_module.dart';
import 'package:rebirth/features/sync/presentation/foreground_auto_sync_controller.dart';
import 'package:rebirth/features/sync/presentation/sync_center_controller.dart';
import 'package:rebirth/features/sync/presentation/sync_center_page.dart';
import 'package:rebirth/features/sync/presentation/sync_center_view_state.dart';

void main() {
  testWidgets('Sync Center shows six user modules and privacy-safe metrics', (
    tester,
  ) async {
    await _pump(tester, _state(), height: 2400);

    expect(find.text('同步中心'), findsOneWidget);
    expect(find.text('在此设备自动同步'), findsOneWidget);
    expect(find.text('未开启'), findsOneWidget);
    expect(find.byKey(const ValueKey('syncAllButton')), findsOneWidget);
    for (final module in const [
      'Profile',
      'Plan',
      'Today',
      'Journal',
      'Health',
      'AI 报告',
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

  testWidgets('automatic sync requires explicit consent before enabling', (
    tester,
  ) async {
    final automatic = await _pump(tester, _state(), height: 2400);

    await tester.tap(find.byKey(const ValueKey('automaticSyncSwitch')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('automaticSyncConsentDialog')),
      findsOneWidget,
    );
    expect(find.textContaining('当前设备和当前账号'), findsOneWidget);
    expect(find.textContaining('AI Chat 不会同步'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(automatic.preferenceChanges, isEmpty);

    await tester.tap(find.byKey(const ValueKey('automaticSyncSwitch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmAutomaticSyncButton')));
    await tester.pumpAndSettle();

    expect(automatic.preferenceChanges, [true]);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('automaticSyncSwitch')),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('automatic activity disables all manual sync actions', (
    tester,
  ) async {
    await _pump(
      tester,
      _state(),
      automaticState: _automaticState(
        status: ForegroundAutoSyncStatus.syncing,
        enabled: true,
        currentModule: SyncModuleId.today,
      ),
      height: 2400,
    );

    expect(find.textContaining('正在自动同步'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('syncAllButton')))
          .onPressed,
      isNull,
    );
    for (final id in SyncModuleId.values) {
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(ValueKey('syncModuleButton-${id.stableId}')),
            )
            .onPressed,
        isNull,
      );
    }
  });

  testWidgets('automatic conflict state exposes the conflict center', (
    tester,
  ) async {
    await _pump(
      tester,
      _state(),
      automaticState: _automaticState(
        status: ForegroundAutoSyncStatus.needsAttention,
        enabled: true,
        conflictCount: 1,
        message: '部分数据需要你在待处理问题中选择版本',
      ),
      height: 2400,
    );

    expect(find.text('部分数据需要你在待处理问题中选择版本'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('automaticSyncConflictButton')),
      findsOneWidget,
    );
  });

  testWidgets('automatic sync switch and status expose readable semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _state(), width: 320, textScale: 2);

    expect(find.bySemanticsLabel(RegExp('在此设备自动同步')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('自动同步状态.*未开启')), findsOneWidget);
    expect(tester.takeException(), isNull);
    handle.dispose();
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

      expect(find.textContaining('2 / 6'), findsOneWidget);
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

Future<_FakeForegroundAutoSyncController> _pump(
  WidgetTester tester,
  SyncCenterViewState value, {
  double width = 900,
  double height = 900,
  double textScale = 1,
  ForegroundAutoSyncState? automaticState,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final automatic = _FakeForegroundAutoSyncController(
    automaticState ?? _automaticState(),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        syncCenterControllerProvider.overrideWith(
          () => _FakeSyncCenterController(value),
        ),
        foregroundAutoSyncControllerProvider.overrideWith(() => automatic),
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
  return automatic;
}

ForegroundAutoSyncState _automaticState({
  ForegroundAutoSyncStatus status = ForegroundAutoSyncStatus.disabled,
  bool enabled = false,
  int conflictCount = 0,
  SyncModuleId? currentModule,
  String? message,
}) {
  return ForegroundAutoSyncState(
    status: status,
    enabled: enabled,
    isForeground: true,
    conflictCount: conflictCount,
    currentModule: currentModule,
    message: message,
  );
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

final class _FakeForegroundAutoSyncController
    extends ForegroundAutoSyncController {
  _FakeForegroundAutoSyncController(this.value);

  final ForegroundAutoSyncState value;
  final List<bool> preferenceChanges = [];

  @override
  ForegroundAutoSyncState build() => value;

  @override
  Future<bool> setEnabled(bool enabled) async {
    preferenceChanges.add(enabled);
    state = state.copyWith(
      enabled: enabled,
      status: enabled
          ? ForegroundAutoSyncStatus.idle
          : ForegroundAutoSyncStatus.disabled,
      clearMessage: true,
    );
    return true;
  }
}
