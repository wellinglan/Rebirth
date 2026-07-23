import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import 'package:rebirth/features/ai_coach/presentation/ai_report_detail_page.dart';

import '../ai_coach_test_support.dart';

void main() {
  testWidgets('Daily detail shows Current without a full hash', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await harness.pumpDetail(tester);

    expect(
      find.byKey(const ValueKey('dailyReportFreshnessCurrent')),
      findsOneWidget,
    );
    expect(find.text('与当前记录一致'), findsOneWidget);
    expect(find.text(_Harness.currentHash), findsNothing);
  });

  testWidgets('Daily detail shows Stale as a valid historical conclusion', (
    tester,
  ) async {
    final harness = _Harness(stale: true);
    addTearDown(harness.dispose);
    await harness.pumpDetail(tester);

    expect(
      find.byKey(const ValueKey('dailyReportFreshnessStale')),
      findsOneWidget,
    );
    expect(find.text('当前记录已发生变化'), findsOneWidget);
    expect(find.text('这份报告仍保留生成时的历史结论。'), findsOneWidget);
  });

  testWidgets('legacy Daily detail shows neutral Unavailable', (tester) async {
    final harness = _Harness(legacy: true);
    addTearDown(harness.dispose);
    await harness.pumpDetail(tester);

    expect(
      find.byKey(const ValueKey('dailyReportFreshnessUnavailable')),
      findsOneWidget,
    );
    expect(find.text('暂时无法确认'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('rebuildDailyPreviewButton')),
      findsNothing,
    );
  });

  testWidgets('Weekly detail has no Daily freshness status', (tester) async {
    final harness = _Harness(weekly: true);
    addTearDown(harness.dispose);
    await harness.pumpDetail(tester);

    expect(
      find.byKey(const ValueKey('dailyReportFreshnessCard')),
      findsNothing,
    );
  });

  testWidgets('Stale action opens the original date and scopes preview', (
    tester,
  ) async {
    final harness = _Harness(
      stale: true,
      scopes: const {AiDataScope.todayMetrics, AiDataScope.journalReflections},
    );
    addTearDown(harness.dispose);
    await harness.pumpRouter(tester);

    await tester.tap(find.byKey(const ValueKey('rebuildDailyPreviewButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('aiDailyInsightPage')), findsOneWidget);
    expect(find.text('目标日期：2026-07-16'), findsOneWidget);
    expect(find.byKey(const ValueKey('aiRequestPreview')), findsOneWidget);
    expect(_scopeValue(tester, AiDataScope.todayMetrics), isTrue);
    expect(_scopeValue(tester, AiDataScope.journalReflections), isTrue);
    expect(_scopeValue(tester, AiDataScope.healthMetrics), isFalse);
  });

  testWidgets('cancelling refreshed generation creates no pending or POST', (
    tester,
  ) async {
    final harness = _Harness(stale: true);
    addTearDown(harness.dispose);
    await harness.pumpRouter(tester);
    await _openRefreshedPreview(tester);

    await _scrollTap(
      tester,
      find.byKey(const ValueKey('generateDailyInsightButton')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cancelAiGenerationButton')));
    await tester.pumpAndSettle();

    expect(harness.reports.createPendingCalls, 0);
    expect(harness.bindings.saveCalls, 0);
    expect(harness.gateway.generationCalls, 0);
  });

  testWidgets('confirmed refresh creates a Current report and keeps old one', (
    tester,
  ) async {
    final harness = _Harness(stale: true);
    addTearDown(harness.dispose);
    await harness.pumpRouter(tester);
    await _openRefreshedPreview(tester);

    await _scrollTap(
      tester,
      find.byKey(const ValueKey('generateDailyInsightButton')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmAiGenerationButton')));
    await tester.pumpAndSettle();

    expect(harness.gateway.dailyGenerationCalls, 1);
    expect(harness.reports.createPendingCalls, 1);
    expect(harness.reports.reports, hasLength(2));
    expect(
      harness.reports.reports.any((report) => report.id == 'old-daily'),
      isTrue,
    );
    expect(
      find.byKey(const ValueKey('dailyReportFreshnessCurrent')),
      findsOneWidget,
    );
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('Stale detail has no overflow at ${width.toInt()} px', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(Size(width, 900));
      final harness = _Harness(stale: true);
      addTearDown(harness.dispose);
      await harness.pumpDetail(tester);

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('rebuildDailyPreviewButton')),
        findsOneWidget,
      );
    });
  }

  testWidgets('Stale detail has no overflow at TextScaler 2.0', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(360, 900));
    final harness = _Harness(stale: true, textScale: 2);
    addTearDown(harness.dispose);
    await harness.pumpDetail(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('当前记录已发生变化'), findsOneWidget);
  });
}

class _Harness {
  _Harness({
    this.stale = false,
    this.legacy = false,
    this.weekly = false,
    this.textScale = 1,
    this.scopes = const {AiDataScope.todayMetrics},
  }) {
    assembler = FakeAiCoachInputAssembler(
      bundle: buildAiBundle(
        reportType: AiReportType.dailyInsight,
        scopes: scopes,
        hash: currentHash,
      ),
    );
    reports = FakeAiReportRepository(
      reports: [
        buildAiReport(
          id: 'old-daily',
          reportType: weekly
              ? AiReportType.weeklyReport
              : AiReportType.dailyInsight,
          selectedScopes: scopes,
          inputHash: stale ? storedHash : currentHash,
          includeFreshnessMetadata: !legacy,
        ),
      ],
    );
    bindings = FakeAiGenerationRequestBindingStore();
    gateway = FakeAiGenerationGateway(capabilities: _dailyCapabilities());
  }

  static const currentHash =
      'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
  static const storedHash =
      '12345678aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa87654321';

  final bool stale;
  final bool legacy;
  final bool weekly;
  final double textScale;
  final Set<AiDataScope> scopes;
  late final FakeAiCoachInputAssembler assembler;
  late final FakeAiReportRepository reports;
  late final FakeAiGenerationRequestBindingStore bindings;
  late final FakeAiGenerationGateway gateway;
  GoRouter? router;

  Future<void> pumpDetail(WidgetTester tester) async {
    await tester.pumpWidget(
      _scope(
        MaterialApp(
          home: const AiReportDetailPage(reportId: 'old-daily'),
          builder: _scaled,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpRouter(WidgetTester tester) async {
    router = GoRouter(
      initialLocation: '/reports/old-daily',
      routes: [
        GoRoute(
          path: '/reports/:reportId',
          builder: (context, state) => AiReportDetailPage(
            reportId: state.pathParameters['reportId'] ?? '',
          ),
        ),
        GoRoute(
          path: '/ai-coach/daily/:targetDate',
          builder: (context, state) => AiDailyInsightPage(
            targetDate: state.pathParameters['targetDate'] ?? '',
            initialScopes: _parseScopes(state.uri.queryParameters['scopes']),
          ),
        ),
        GoRoute(
          path: '/ai-coach/reports/:reportId',
          builder: (context, state) => AiReportDetailPage(
            reportId: state.pathParameters['reportId'] ?? '',
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      _scope(MaterialApp.router(routerConfig: router!, builder: _scaled)),
    );
    await tester.pumpAndSettle();
  }

  Widget _scope(Widget child) {
    return ProviderScope(
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
            session: AuthSession(
              accessToken: 'token',
              refreshToken: 'refresh',
              user: AuthUser(id: 'user', displayName: 'Test'),
            ),
          ),
        ),
      ],
      child: child,
    );
  }

  Widget _scaled(BuildContext context, Widget? child) {
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    );
  }

  void dispose() => router?.dispose();
}

bool _scopeValue(WidgetTester tester, AiDataScope scope) {
  return tester
          .widget<CheckboxListTile>(
            find.byKey(ValueKey('aiScope-${scope.contractValue}')),
          )
          .value ??
      false;
}

Set<AiDataScope> _parseScopes(String? value) {
  if (value == null) return const {};
  return AiDataScope.values
      .where((scope) => value.split(',').contains(scope.contractValue))
      .toSet();
}

Future<void> _openRefreshedPreview(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('rebuildDailyPreviewButton')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('aiRequestPreview')), findsOneWidget);
}

Future<void> _scrollTap(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

AiGenerationCapabilities _dailyCapabilities() => AiGenerationCapabilities(
  enabled: true,
  provider: 'fake',
  providerLabel: 'Development Fake',
  model: 'deterministic-test-provider',
  supportedReportTypes: const ['daily_insight'],
  promptVersions: const ['daily-insight-v1'],
  reportContracts: [
    AiGenerationReportContract(
      reportType: 'daily_insight',
      promptVersions: ['daily-insight-v1'],
      inputSchemaVersion: 1,
      outputSchemaVersion: 1,
      periodKind: AiReportPeriodKind.singleDay,
      supportedScopes: [
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
