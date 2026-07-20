import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_authorization.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_report_contract.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_daily_insight_page.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_manual_generation_controller.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_manual_generation_view_state.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_request_preview_controller.dart';
import 'package:rebirth/features/ai_coach/presentation/models/ai_insight_request_context.dart';

import '../ai_coach_test_support.dart';

const _date = '2026-07-16';
const _requestContext = AiInsightRequestContext.daily(_date);

void main() {
  test('request context has stable equality and isolates date and type', () {
    expect(_requestContext, const AiInsightRequestContext.daily(_date));
    expect(
      _requestContext.hashCode,
      const AiInsightRequestContext.daily(_date).hashCode,
    );
    expect(
      _requestContext,
      isNot(const AiInsightRequestContext.daily('2026-07-15')),
    );
    expect(_requestContext, isNot(const AiInsightRequestContext.weekly()));
  });

  test('family keeps selections isolated between Daily dates', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    const other = AiInsightRequestContext.daily('2026-07-15');
    final first = harness.container.listen(
      aiRequestPreviewControllerFamily(_requestContext),
      (_, _) {},
    );
    final second = harness.container.listen(
      aiRequestPreviewControllerFamily(other),
      (_, _) {},
    );
    addTearDown(first.close);
    addTearDown(second.close);
    await harness.container.read(
      aiRequestPreviewControllerFamily(_requestContext).future,
    );
    await harness.container.read(
      aiRequestPreviewControllerFamily(other).future,
    );

    harness.container
        .read(aiRequestPreviewControllerFamily(_requestContext).notifier)
        .toggleScope(AiDataScope.todayMetrics, selected: true);

    expect(
      harness.container
          .read(aiRequestPreviewControllerFamily(_requestContext))
          .requireValue
          .selectedScopes,
      {AiDataScope.todayMetrics},
    );
    expect(
      harness.container
          .read(aiRequestPreviewControllerFamily(other))
          .requireValue
          .selectedScopes,
      isEmpty,
    );
  });

  test('Daily preview dispatches only buildDailyInsight', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await harness.container.read(
      aiRequestPreviewControllerFamily(_requestContext).future,
    );
    final controller = harness.container.read(
      aiRequestPreviewControllerFamily(_requestContext).notifier,
    );
    expect(
      controller.toggleScope(AiDataScope.growthSummary, selected: true),
      AiScopeToggleResult.ignored,
    );
    controller.toggleScope(AiDataScope.todayMetrics, selected: true);

    expect(await controller.buildPreview(), isTrue);
    expect(harness.assembler.dailyBuildCalls, 1);
    expect(harness.assembler.weeklyBuildCalls, 0);
    final state = harness.container
        .read(aiRequestPreviewControllerFamily(_requestContext))
        .requireValue;
    expect(state.periodStartDate, _date);
    expect(state.periodEndDate, _date);
    expect(state.promptVersion, 'daily-insight-v1');
  });

  test('Daily generation dispatches Daily endpoint and never Weekly', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await harness.container.read(
      aiRequestPreviewControllerFamily(_requestContext).future,
    );
    final preview = harness.container.read(
      aiRequestPreviewControllerFamily(_requestContext).notifier,
    );
    preview.toggleScope(AiDataScope.todayMetrics, selected: true);
    await preview.buildPreview();
    final bundle = harness.container
        .read(aiRequestPreviewControllerFamily(_requestContext))
        .requireValue
        .bundle!;
    await harness.container.read(
      aiManualGenerationControllerFamily(_requestContext).future,
    );

    final result = await harness.container
        .read(aiManualGenerationControllerFamily(_requestContext).notifier)
        .submit(bundle);

    expect(result?.completed, isTrue);
    expect(harness.gateway.dailyGenerationCalls, 1);
    expect(harness.gateway.weeklyGenerationCalls, 0);
    expect(harness.reports.createPendingCalls, 1);
    expect(harness.bindings.values, isEmpty);
  });

  test(
    'changed source blocks pending, binding, capabilities and POST',
    () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      await harness.container.read(
        aiRequestPreviewControllerFamily(_requestContext).future,
      );
      final preview = harness.container.read(
        aiRequestPreviewControllerFamily(_requestContext).notifier,
      );
      preview.toggleScope(AiDataScope.todayMetrics, selected: true);
      await preview.buildPreview();
      final oldBundle = harness.container
          .read(aiRequestPreviewControllerFamily(_requestContext))
          .requireValue
          .bundle!;
      harness.assembler.bundle = buildAiBundle(
        reportType: AiReportType.dailyInsight,
        scopes: {AiDataScope.todayMetrics},
        hash:
            'abcdef01aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa10fedcba',
      );
      await harness.container.read(
        aiManualGenerationControllerFamily(_requestContext).future,
      );
      final initialCapabilitiesCalls = harness.gateway.capabilitiesCalls;

      final capabilities = await harness.container
          .read(aiManualGenerationControllerFamily(_requestContext).notifier)
          .prepareForConfirmation(oldBundle);

      expect(capabilities, isNull);
      expect(harness.reports.createPendingCalls, 0);
      expect(harness.bindings.saveCalls, 0);
      expect(harness.gateway.generationCalls, 0);
      expect(harness.gateway.capabilitiesCalls, initialCapabilitiesCalls);
      expect(
        harness.container
            .read(aiRequestPreviewControllerFamily(_requestContext))
            .requireValue
            .buildError,
        '当天记录已发生变化，请重新查看预览。',
      );
    },
  );

  test(
    'change after preflight blocks final submit without pending or POST',
    () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      await harness.container.read(
        aiRequestPreviewControllerFamily(_requestContext).future,
      );
      final preview = harness.container.read(
        aiRequestPreviewControllerFamily(_requestContext).notifier,
      );
      preview.toggleScope(AiDataScope.todayMetrics, selected: true);
      await preview.buildPreview();
      final oldBundle = harness.container
          .read(aiRequestPreviewControllerFamily(_requestContext))
          .requireValue
          .bundle!;
      await harness.container.read(
        aiManualGenerationControllerFamily(_requestContext).future,
      );
      final generation = harness.container.read(
        aiManualGenerationControllerFamily(_requestContext).notifier,
      );
      expect(await generation.prepareForConfirmation(oldBundle), isNotNull);
      harness.assembler.bundle = buildAiBundle(
        reportType: AiReportType.dailyInsight,
        scopes: {AiDataScope.todayMetrics},
        hash:
            'abcdef02aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa20fedcba',
      );

      expect(await generation.submit(oldBundle), isNull);
      expect(harness.reports.createPendingCalls, 0);
      expect(harness.bindings.saveCalls, 0);
      expect(harness.gateway.generationCalls, 0);
    },
  );

  test('Daily capabilities reject a non-single-day typed contract', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    harness.gateway.capabilities = _dailyCapabilities(
      periodKind: AiReportPeriodKind.sevenDays,
    );
    await harness.container.read(
      aiRequestPreviewControllerFamily(_requestContext).future,
    );
    final preview = harness.container.read(
      aiRequestPreviewControllerFamily(_requestContext).notifier,
    );
    preview.toggleScope(AiDataScope.todayMetrics, selected: true);
    await preview.buildPreview();

    final state = await harness.container.read(
      aiManualGenerationControllerFamily(_requestContext).future,
    );

    expect(state.phase, AiManualGenerationPhase.failure);
    expect(harness.reports.createPendingCalls, 0);
    expect(harness.gateway.generationCalls, 0);
  });

  testWidgets('invalid route date is safe and creates no AI state', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const MaterialApp(
          home: AiDailyInsightPage(targetDate: '2026-02-30'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('invalidDailyInsightDatePage')),
      findsOneWidget,
    );
    expect(find.textContaining('目标日期无效'), findsOneWidget);
    expect(harness.assembler.buildCalls, 0);
    expect(harness.gateway.capabilitiesCalls, 0);
  });

  testWidgets('Daily starts empty and exposes only three scopes', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await _pumpPage(tester, harness);

    expect(find.text('目标日期：2026-07-16'), findsOneWidget);
    for (final scope in [
      'today_metrics',
      'health_metrics',
      'journal_reflections',
    ]) {
      expect(find.byKey(ValueKey('aiScope-$scope')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('aiScope-growth_summary')), findsNothing);
    expect(find.textContaining('全选'), findsNothing);
    expect(
      find.byKey(const ValueKey('buildDailyInsightPreviewButton')),
      findsOneWidget,
    );
    expect(harness.assembler.buildCalls, 0);
    expect(harness.gateway.capabilitiesCalls, 0);
  });

  testWidgets(
    'all missing shows source links without capabilities or generate',
    (tester) async {
      final harness = _Harness(sourceCount: 0);
      addTearDown(harness.dispose);
      await _pumpPage(tester, harness);
      await tester.tap(find.byKey(const ValueKey('aiScope-today_metrics')));
      await tester.pump();
      final buildButton = find.byKey(
        const ValueKey('buildDailyInsightPreviewButton'),
      );
      await Scrollable.ensureVisible(tester.element(buildButton));
      await tester.pumpAndSettle();
      await tester.tap(buildButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('dailyInsightNoSources')),
        findsOneWidget,
      );
      expect(find.text('返回 Today'), findsOneWidget);
      expect(find.text('返回 Health'), findsOneWidget);
      expect(find.text('返回 Journal'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('generateDailyInsightButton')),
        findsNothing,
      );
      expect(harness.gateway.capabilitiesCalls, 0);
      expect(harness.reports.createPendingCalls, 0);
    },
  );

  testWidgets('Daily page has no overflow at target widths and 2x text', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 360.0, 412.0, 720.0, 840.0, 1200.0]) {
      final harness = _Harness();
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const AiDailyInsightPage(targetDate: _date),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width $width');
      harness.dispose();
    }
  });
}

final class _Harness {
  _Harness({int sourceCount = 1}) {
    assembler = FakeAiCoachInputAssembler(
      bundle: buildAiBundle(
        reportType: AiReportType.dailyInsight,
        scopes: {AiDataScope.todayMetrics},
        sourceCount: sourceCount,
      ),
    );
    reports = FakeAiReportRepository();
    bindings = FakeAiGenerationRequestBindingStore();
    gateway = FakeAiGenerationGateway(capabilities: _dailyCapabilities());
    container = ProviderContainer(
      overrides: [
        aiConsentRepositoryProvider.overrideWithValue(
          FakeAiConsentRepository(
            authorization: AiDataAuthorization(enabled: true, consentAt: 1),
          ),
        ),
        aiCoachInputAssemblerProvider.overrideWithValue(assembler),
        aiReportRepositoryProvider.overrideWithValue(reports),
        aiGenerationRequestBindingStoreProvider.overrideWithValue(bindings),
        aiGenerationGatewayProvider.overrideWithValue(gateway),
        authSessionStoreProvider.overrideWithValue(
          FakeAuthSessionStore(
            session: const AuthSession(
              accessToken: 'token',
              refreshToken: 'refresh',
              user: AuthUser(id: 'user', displayName: 'Test'),
            ),
          ),
        ),
        dateTimeServiceProvider.overrideWithValue(
          DateTimeService(now: () => DateTime(2026, 7, 16, 9)),
        ),
      ],
    );
  }

  late final ProviderContainer container;
  late final FakeAiCoachInputAssembler assembler;
  late final FakeAiReportRepository reports;
  late final FakeAiGenerationRequestBindingStore bindings;
  late final FakeAiGenerationGateway gateway;

  void dispose() => container.dispose();
}

AiGenerationCapabilities _dailyCapabilities({
  AiReportPeriodKind periodKind = AiReportPeriodKind.singleDay,
}) => AiGenerationCapabilities(
  enabled: true,
  provider: 'fake',
  providerLabel: 'Development Fake',
  model: 'deterministic-test-provider',
  supportedReportTypes: const ['daily_insight', 'weekly_report'],
  promptVersions: const ['daily-insight-v1', 'weekly-report-v1'],
  reportContracts: [
    AiGenerationReportContract(
      reportType: 'daily_insight',
      promptVersions: const ['daily-insight-v1'],
      inputSchemaVersion: 1,
      outputSchemaVersion: 1,
      periodKind: periodKind,
      supportedScopes: const [
        'today_metrics',
        'health_metrics',
        'journal_reflections',
      ],
    ),
  ],
  inputSchemaVersion: 1,
  outputSchemaVersion: 1,
  streaming: false,
  responseStorageRequested: false,
);

Future<void> _pumpPage(WidgetTester tester, _Harness harness) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.container,
      child: const MaterialApp(home: AiDailyInsightPage(targetDate: _date)),
    ),
  );
  await tester.pumpAndSettle();
}
