import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_authorization.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';
import 'package:rebirth/features/ai_coach/domain/ai_usage_snapshot.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_coach_page.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_report_detail_page.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_weekly_report_page.dart';
import 'package:rebirth/features/ai_reports/presentation/ai_report_library_page.dart';
import 'package:rebirth/features/settings/presentation/ai_consent_settings_page.dart';

import '../ai_coach_test_support.dart';

void main() {
  testWidgets('home presents tasks, usage, and recent reports naturally', (
    tester,
  ) async {
    final gateway = FakeAiGenerationGateway();
    final reports = FakeAiReportRepository(
      reports: [
        buildAiReport(
          id: 'daily-existing',
          reportType: AiReportType.dailyInsight,
          targetDate: '2026-07-16',
        ),
        buildAiReport(id: 'weekly-existing'),
      ],
    );
    await _pumpHome(tester, gateway: gateway, reports: reports);

    expect(find.text('AI 教练'), findsOneWidget);
    expect(find.text('洞察与回顾'), findsOneWidget);
    expect(find.byKey(const ValueKey('startAiChatButton')), findsOneWidget);
    expect(find.text('和 AI 教练聊一聊'), findsOneWidget);
    expect(find.text('AI 可用'), findsOneWidget);
    expect(find.textContaining('今天剩余 8 次'), findsOneWidget);
    expect(find.text('今日洞察'), findsOneWidget);
    expect(find.text('每周回顾'), findsOneWidget);
    expect(find.text('查看今日洞察'), findsOneWidget);
    expect(find.text('查看本周报告'), findsOneWidget);
    expect(find.byKey(const ValueKey('aiCoachRecentReports')), findsOneWidget);
    expect(find.text('查看全部'), findsOneWidget);
    for (final engineeringTerm in [
      'Prompt Version',
      'Input Hash',
      'Request Binding',
      'Generation Gateway',
    ]) {
      expect(find.textContaining(engineeringTerm), findsNothing);
    }
    expect(gateway.generationCalls, 0);
  });

  testWidgets('existing report CTA opens canonical detail without generation', (
    tester,
  ) async {
    final gateway = FakeAiGenerationGateway();
    final reports = FakeAiReportRepository(
      reports: [buildAiReport(id: 'weekly-existing')],
    );
    final router = _router();
    addTearDown(router.dispose);
    await _pumpHome(tester, gateway: gateway, reports: reports, router: router);

    await tester.ensureVisible(find.text('查看本周报告'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看本周报告'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('aiReportDetailPage')), findsOneWidget);
    expect(router.state.matchedLocation, '/ai-reports/weekly-existing');
    expect(gateway.generationCalls, 0);
  });

  testWidgets('new weekly task enters the natural generation flow', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await _pumpHome(
      tester,
      gateway: FakeAiGenerationGateway(),
      reports: FakeAiReportRepository(),
      router: router,
    );

    await tester.ensureVisible(find.text('生成每周回顾'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('生成每周回顾'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('aiWeeklyReportPage')), findsOneWidget);
    expect(find.text('查看本次使用的数据'), findsOneWidget);
    expect(router.state.matchedLocation, RoutePaths.aiCoachWeekly);
  });

  testWidgets('unavailable states stay distinct and never generate', (
    tester,
  ) async {
    for (final scenario in [
      (
        const AiUsageSnapshot(
          availability: AiUsageAvailability.disabled,
          enabled: false,
          dailyLimit: 4,
          used: 0,
          remaining: 4,
          resetsAtUtcMilliseconds: null,
        ),
        'AI 服务当前暂不可用',
      ),
      (
        const AiUsageSnapshot(
          availability: AiUsageAvailability.limitReached,
          enabled: true,
          dailyLimit: 4,
          used: 4,
          remaining: 0,
          resetsAtUtcMilliseconds: 1784246400000,
        ),
        '今天的 AI 次数已用完',
      ),
      (const AiUsageSnapshot.unknown(), '暂时无法确认 AI 使用状态'),
    ]) {
      final gateway = FakeAiGenerationGateway(usage: scenario.$1);
      await _pumpHome(
        tester,
        gateway: gateway,
        reports: FakeAiReportRepository(),
      );
      expect(find.text(scenario.$2), findsOneWidget);
      if (scenario.$1.availability != AiUsageAvailability.unknown) {
        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('aiCoachTaskAction-weekly')),
        );
        expect(button.onPressed, isNull);
      }
      expect(gateway.generationCalls, 0);
    }
  });

  testWidgets('consent action opens settings and returns to the coach', (
    tester,
  ) async {
    final consent = FakeAiConsentRepository(
      authorization: const AiDataAuthorization.disabled(),
    );
    final router = _router();
    addTearDown(router.dispose);
    await _pumpHome(
      tester,
      gateway: FakeAiGenerationGateway(),
      reports: FakeAiReportRepository(),
      consent: consent,
      router: router,
    );

    expect(find.text('设置 AI 授权'), findsWidgets);
    await tester.ensureVisible(
      find.byKey(const ValueKey('openAiConsentSettingsButton')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('openAiConsentSettingsButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('aiConsentSettingsPage')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('enableAiDataSharingButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmAiDataConsentButton')));
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('aiCoachPage')), findsOneWidget);
    expect(find.byKey(const ValueKey('aiConsentGate')), findsNothing);
  });

  testWidgets('home and task cards do not overflow target viewports', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 360.0, 412.0, 1200.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await _pumpHome(
        tester,
        gateway: FakeAiGenerationGateway(),
        reports: FakeAiReportRepository(),
        textScale: 2,
      );
      expect(find.byKey(const ValueKey('aiCoachPage')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });
}

GoRouter _router() => GoRouter(
  initialLocation: RoutePaths.aiCoach,
  routes: [
    GoRoute(path: RoutePaths.aiCoach, builder: (_, _) => const AiCoachPage()),
    GoRoute(
      path: RoutePaths.aiCoachWeekly,
      builder: (_, _) => const AiWeeklyReportPage(),
    ),
    GoRoute(
      path: RoutePaths.settingsAiConsent,
      builder: (_, _) => const AiConsentSettingsPage(),
    ),
    GoRoute(
      path: RoutePaths.aiReports,
      builder: (_, _) => const AiReportLibraryPage(),
      routes: [
        GoRoute(
          path: ':reportId',
          builder: (_, state) => AiReportDetailPage(
            reportId: state.pathParameters['reportId'] ?? '',
          ),
        ),
      ],
    ),
  ],
);

Future<void> _pumpHome(
  WidgetTester tester, {
  required FakeAiGenerationGateway gateway,
  required FakeAiReportRepository reports,
  FakeAiConsentRepository? consent,
  GoRouter? router,
  double textScale = 1,
}) async {
  final child = router == null
      ? MaterialApp(home: const AiCoachPage(), builder: _scaled(textScale))
      : MaterialApp.router(routerConfig: router, builder: _scaled(textScale));
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        aiConsentRepositoryProvider.overrideWithValue(
          consent ??
              FakeAiConsentRepository(
                authorization: AiDataAuthorization(enabled: true, consentAt: 1),
              ),
        ),
        aiCoachInputAssemblerProvider.overrideWithValue(
          FakeAiCoachInputAssembler(),
        ),
        aiReportRepositoryProvider.overrideWithValue(reports),
        aiGenerationGatewayProvider.overrideWithValue(gateway),
        dateTimeServiceProvider.overrideWithValue(
          DateTimeService(now: () => DateTime(2026, 7, 16, 9)),
        ),
      ],
      child: child,
    ),
  );
  await tester.pumpAndSettle();
}

TransitionBuilder _scaled(double scale) =>
    (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    );
