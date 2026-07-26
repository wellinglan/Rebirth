import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/account/domain/account_boundary.dart';
import 'package:rebirth/features/account/presentation/auth_gate_status_pages.dart';
import 'package:rebirth/features/account/presentation/legacy_data_resolution_controller.dart';

void main() {
  testWidgets('shows privacy-safe summaries for multiple local spaces', (
    tester,
  ) async {
    final controller = _FakeLegacyController(_state);
    await _pump(tester, controller: controller);

    expect(find.text('本地数据空间 1'), findsOneWidget);
    expect(find.text('本地数据空间 2'), findsOneWidget);
    expect(find.textContaining('Today：2'), findsOneWidget);
    expect(find.textContaining('冲突历史：有'), findsOneWidget);
    expect(find.textContaining('private journal body'), findsNothing);
    expect(find.textContaining('00000000-0000'), findsNothing);
    expect(find.textContaining('https://'), findsNothing);
  });

  testWidgets('claim requires confirmation and cancellation changes nothing', (
    tester,
  ) async {
    final controller = _FakeLegacyController(_state);
    await _pump(tester, controller: controller);

    await tester.tap(
      find.byKey(const ValueKey('claimLegacySpaceButton-local-space-1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('claimLegacyConfirmationDialog')),
      findsOneWidget,
    );
    expect(find.textContaining('本地记录不会上传'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('cancelOwnershipConfirmationButton')),
    );
    await tester.pumpAndSettle();
    expect(controller.claimedKeys, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey('claimLegacySpaceButton-local-space-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmOwnershipButton')));
    await tester.pumpAndSettle();
    expect(controller.claimedKeys, ['local-space-1']);
  });

  testWidgets('fresh space and logout remain explicit actions', (tester) async {
    final controller = _FakeLegacyController(_state);
    await _pump(tester, controller: controller);

    await tester.ensureVisible(
      find.byKey(const ValueKey('createFreshDataSpaceButton')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('createFreshDataSpaceButton')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('createFreshConfirmationDialog')),
      findsOneWidget,
    );
    expect(find.textContaining('旧数据不会删除'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirmOwnershipButton')));
    await tester.pumpAndSettle();
    expect(controller.createFreshCalls, 1);

    await tester.tap(find.byKey(const ValueKey('bindingRequiredLogoutButton')));
    await tester.pump();
    expect(controller.logoutCalls, 1);
  });

  testWidgets('shows loading and controlled summary error states', (
    tester,
  ) async {
    final loading = _LoadingLegacyController();
    await _pump(tester, controller: loading, settle: false);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('legacyDataSummariesLoading')),
      findsOneWidget,
    );
    loading.complete(_state);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('legacyDataResolutionList')),
      findsOneWidget,
    );

    await _pump(tester, controller: _ErrorLegacyController());
    expect(
      find.byKey(const ValueKey('retryLegacyDataSummariesButton')),
      findsOneWidget,
    );
    expect(find.textContaining('任何数据都没有被修改'), findsOneWidget);
  });

  for (final width in <double>[320, 360, 412, 720, 840, 1200]) {
    testWidgets('has no overflow at width $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pump(
        tester,
        controller: _FakeLegacyController(_state),
        width: width,
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('legacyDataResolutionList')),
        findsOneWidget,
      );
    });
  }

  testWidgets('supports text scale 2.0 and scrollable confirmation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(
      tester,
      controller: _FakeLegacyController(_state),
      width: 320,
      textScaler: const TextScaler.linear(2),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('createFreshDataSpaceButton')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('createFreshDataSpaceButton')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(
      find.byKey(const ValueKey('confirmOwnershipButton')),
      findsOneWidget,
    );
  });

  testWidgets('claim action exposes a readable semantics label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, controller: _FakeLegacyController(_state));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == '将本地数据空间 1归属到当前账号',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required LegacyDataResolutionController controller,
  double width = 720,
  TextScaler textScaler = TextScaler.noScaling,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        legacyDataResolutionControllerProvider.overrideWith(() => controller),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 780), textScaler: textScaler),
          child: const AccountBindingRequiredPage(),
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

final class _FakeLegacyController extends LegacyDataResolutionController {
  _FakeLegacyController(this.initial);

  final LegacyDataResolutionState initial;
  final List<String> claimedKeys = [];
  int createFreshCalls = 0;
  int logoutCalls = 0;

  @override
  Future<LegacyDataResolutionState> build() async => initial;

  @override
  Future<bool> claim(String selectionKey) async {
    claimedKeys.add(selectionKey);
    return true;
  }

  @override
  Future<bool> createFreshSpace() async {
    createFreshCalls += 1;
    return true;
  }

  @override
  Future<void> logout() async {
    logoutCalls += 1;
  }
}

final class _LoadingLegacyController extends LegacyDataResolutionController {
  final Completer<LegacyDataResolutionState> _completer = Completer();

  @override
  Future<LegacyDataResolutionState> build() => _completer.future;

  void complete(LegacyDataResolutionState value) => _completer.complete(value);
}

final class _ErrorLegacyController extends LegacyDataResolutionController {
  @override
  Future<LegacyDataResolutionState> build() {
    throw StateError('summary failed');
  }
}

const _state = LegacyDataResolutionState(
  summaries: [
    LegacyLocalDataSpaceSummary(
      selectionKey: 'local-space-1',
      displayIndex: 1,
      profileCreatedDate: '2026-07-20',
      latestBusinessUpdatedAt: 1785000000000,
      todayCount: 2,
      journalCount: 3,
      goalCount: 4,
      healthCount: 5,
      aiReportCount: 1,
      tombstoneCount: 1,
      hasSyncHistory: true,
      hasConflictHistory: true,
      hasAiPending: true,
      isAlreadyBound: false,
    ),
    LegacyLocalDataSpaceSummary(
      selectionKey: 'local-space-2',
      displayIndex: 2,
      profileCreatedDate: '2026-07-21',
      latestBusinessUpdatedAt: null,
      todayCount: 0,
      journalCount: 0,
      goalCount: 0,
      healthCount: 0,
      aiReportCount: 0,
      tombstoneCount: 0,
      hasSyncHistory: false,
      hasConflictHistory: false,
      hasAiPending: false,
      isAlreadyBound: false,
    ),
  ],
);
