import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_authorization.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_request_binding.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_coach_page.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_report_detail_page.dart';

import '../ai_coach_test_support.dart';

void main() {
  testWidgets('consent gate is local-only and does not call the assembler', (
    tester,
  ) async {
    final consent = FakeAiConsentRepository(
      authorization: const AiDataAuthorization.disabled(),
    );
    final assembler = FakeAiCoachInputAssembler();
    await _pumpAiCoach(
      tester,
      consent: consent,
      assembler: assembler,
      reports: FakeAiReportRepository(),
    );

    expect(find.byKey(const ValueKey('aiConsentGate')), findsOneWidget);
    expect(find.text('AI 数据使用尚未启用'), findsOneWidget);
    expect(find.textContaining('当前不会准备任何 AI 输入'), findsOneWidget);
    expect(find.textContaining('只有最终确认后'), findsOneWidget);
    expect(assembler.buildCalls, 0);
    expect(consent.grantCalls, 0);
  });

  testWidgets('authorized page starts empty with accessible unchecked scopes', (
    tester,
  ) async {
    await _pumpAiCoach(
      tester,
      consent: _enabledConsent(),
      assembler: FakeAiCoachInputAssembler(),
      reports: FakeAiReportRepository(),
    );

    final buildButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('buildAiPreviewButton')),
    );
    expect(buildButton.onPressed, isNull);
    expect(find.text('请至少选择一个数据范围。'), findsOneWidget);
    expect(find.text('成长趋势汇总'), findsOneWidget);
    expect(find.text('Journal 复盘内容'), findsOneWidget);
    final growthSemantics = tester.widget<Semantics>(
      find.byKey(const ValueKey('aiScopeSemantics-growth_summary')),
    );
    final journalSemantics = tester.widget<Semantics>(
      find.byKey(const ValueKey('aiScopeSemantics-journal_reflections')),
    );
    expect(growthSemantics.properties.checked, isFalse);
    expect(journalSemantics.properties.checked, isFalse);
    expect(journalSemantics.properties.label, contains('私人'));
  });

  testWidgets(
    'Journal cancellation stays off and confirmation is selection-only',
    (tester) async {
      final consent = _enabledConsent();
      await _pumpAiCoach(
        tester,
        consent: consent,
        assembler: FakeAiCoachInputAssembler(),
        reports: FakeAiReportRepository(),
      );

      await _tapAfterScrolling(
        tester,
        find.byKey(const ValueKey('aiScope-journal_reflections')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('aiJournalScopeDialog')),
        findsOneWidget,
      );
      expect(find.textContaining('不会发送网络'), findsOneWidget);
      expect(find.textContaining('不会自动保存输入快照'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('cancelAiJournalScopeButton')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(
              find.byKey(
                const ValueKey('aiScopeSemantics-journal_reflections'),
              ),
            )
            .properties
            .checked,
        isFalse,
      );

      await _tapAfterScrolling(
        tester,
        find.byKey(const ValueKey('aiScope-journal_reflections')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('confirmAiJournalScopeButton')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(
              find.byKey(
                const ValueKey('aiScopeSemantics-journal_reflections'),
              ),
            )
            .properties
            .checked,
        isTrue,
      );
      expect(consent.grantCalls, 0);
    },
  );

  testWidgets(
    'preview shows typed minimized data and opens a reusable report',
    (tester) async {
      final reusable = buildAiReport(id: 'reusable');
      final reports = FakeAiReportRepository(reports: [reusable])
        ..reusable = reusable;
      final assembler = FakeAiCoachInputAssembler();
      final router = GoRouter(
        initialLocation: '/ai-coach',
        routes: [
          GoRoute(
            path: '/ai-coach',
            builder: (context, state) => const AiCoachPage(),
            routes: [
              GoRoute(
                path: 'reports/:reportId',
                builder: (context, state) => AiReportDetailPage(
                  reportId: state.pathParameters['reportId'] ?? '',
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await _pumpAiCoach(
        tester,
        consent: _enabledConsent(),
        assembler: assembler,
        reports: reports,
        router: router,
      );

      for (final scope in [
        'growth_summary',
        'today_metrics',
        'health_metrics',
      ]) {
        await _tapAfterScrolling(
          tester,
          find.byKey(ValueKey('aiScope-$scope')),
        );
        await tester.pump();
      }
      await _tapAfterScrolling(
        tester,
        find.byKey(const ValueKey('aiScope-journal_reflections')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('confirmAiJournalScopeButton')),
      );
      await tester.pumpAndSettle();
      await _tapAfterScrolling(
        tester,
        find.byKey(const ValueKey('buildAiPreviewButton')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('aiRequestPreview')), findsOneWidget);
      final liveRegion = tester.widget<Semantics>(
        find.byKey(const ValueKey('aiRequestPreviewLiveRegion')),
      );
      expect(liveRegion.properties.liveRegion, isTrue);
      expect(find.text('12345678…87654321'), findsOneWidget);
      expect(find.text('Daily Note 未包含；Priority 文本未包含。'), findsOneWidget);
      expect(find.text('Health Note 未包含；外部来源标识未包含。'), findsOneWidget);
      expect(find.text('一段私人经历'), findsOneWidget);
      expect(find.text('未填写'), findsWidgets);
      expect(find.textContaining('private canonical content'), findsNothing);
      expect(find.textContaining('excluded-user'), findsNothing);
      expect(
        find.byKey(const ValueKey('aiReusableReportCard')),
        findsOneWidget,
      );
      expect(reports.createPendingCalls, 0);

      final openButton = find.byKey(const ValueKey('openReusableReportButton'));
      await _tapAfterScrolling(tester, openButton);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('aiReportDetailPage')), findsOneWidget);
      expect(find.text('这是本地保存的报告正文。'), findsOneWidget);
    },
  );

  testWidgets('history uses text statuses and a complete soft-delete warning', (
    tester,
  ) async {
    final reports = FakeAiReportRepository(
      reports: [
        buildAiReport(id: 'completed'),
        buildAiReport(id: 'pending', status: AiReportStatus.pending),
        buildAiReport(id: 'failed', status: AiReportStatus.failed),
      ],
    );
    await _pumpAiCoach(
      tester,
      consent: _enabledConsent(),
      assembler: FakeAiCoachInputAssembler(),
      reports: reports,
    );

    await tester.tap(find.widgetWithText(Tab, '本地报告'));
    await tester.pumpAndSettle();
    expect(find.text('已完成'), findsOneWidget);
    expect(find.text('待处理'), findsOneWidget);
    expect(find.text('生成失败'), findsOneWidget);
    expect(find.text('检查服务器状态'), findsOneWidget);
    expect(find.byTooltip('删除本地报告'), findsNWidgets(3));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('aiReportCard-pending')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('deleteAiReport-completed')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('aiReportDeleteDialog')), findsOneWidget);
    for (final source in ['Today', 'Journal', 'Health', 'Plan', 'Growth']) {
      expect(find.textContaining(source), findsWidgets);
    }
    expect(find.textContaining('不会改变 AI 数据授权'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cancelAiReportDeleteButton')));
    await tester.pumpAndSettle();
    expect(reports.deleteCalls, 0);
  });

  testWidgets('history mixes Daily single dates with Weekly ranges', (
    tester,
  ) async {
    final reports = FakeAiReportRepository(
      reports: [
        buildAiReport(
          id: 'daily',
          reportType: AiReportType.dailyInsight,
          targetDate: '2026-07-16',
        ),
        buildAiReport(id: 'weekly'),
      ],
    );
    await _pumpAiCoach(
      tester,
      consent: _enabledConsent(),
      assembler: FakeAiCoachInputAssembler(),
      reports: reports,
    );
    await tester.tap(find.widgetWithText(Tab, '本地报告'));
    await tester.pumpAndSettle();

    expect(find.text('每日洞察'), findsOneWidget);
    expect(find.text('每周回顾'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('aiReportCard-daily')),
        matching: find.text('2026-07-16'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('aiReportCard-daily')),
        matching: find.textContaining('至'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'report detail handles completed, pending, failed, and invalid IDs',
    (tester) async {
      final reports = FakeAiReportRepository(
        reports: [
          buildAiReport(
            id: 'completed',
            hasInputSnapshot: true,
            provider: null,
            model: null,
          ),
          buildAiReport(id: 'pending', status: AiReportStatus.pending),
          buildAiReport(id: 'failed', status: AiReportStatus.failed),
        ],
      );

      await _pumpDetail(tester, reports, 'completed');
      expect(find.text('这是本地保存的报告正文。'), findsOneWidget);
      expect(find.text('Provider：未记录'), findsOneWidget);
      expect(find.text('Model：未记录'), findsOneWidget);
      expect(find.text('输入快照：已保存'), findsOneWidget);
      expect(find.textContaining('not displayed'), findsNothing);

      await _pumpDetail(tester, reports, 'pending');
      expect(find.textContaining('请求结果待确认'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('checkAiRequestStatusDetailButton')),
        findsOneWidget,
      );

      await _pumpDetail(tester, reports, 'failed');
      expect(find.textContaining('请求未能完成'), findsOneWidget);
      expect(find.textContaining('StackTrace'), findsOneWidget);
      expect(find.textContaining('SQL path'), findsNothing);

      await _pumpDetail(tester, reports, 'missing');
      expect(
        find.byKey(const ValueKey('aiReportDetailNotFound')),
        findsOneWidget,
      );
    },
  );

  testWidgets('Daily detail uses one date and exposes source navigation', (
    tester,
  ) async {
    final reports = FakeAiReportRepository(
      reports: [
        buildAiReport(
          id: 'daily-detail',
          reportType: AiReportType.dailyInsight,
          targetDate: '2026-07-16',
        ),
      ],
    );
    await _pumpDetail(tester, reports, 'daily-detail');

    expect(find.text('每日洞察'), findsOneWidget);
    expect(find.text('目标日期：2026-07-16'), findsOneWidget);
    expect(find.textContaining('2026-07-16 至'), findsNothing);
    expect(
      find.byKey(const ValueKey('openDailySourceTodayButton')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('openDailySourceJournalButton')),
      findsOneWidget,
    );
    expect(find.textContaining('明日建议'), findsNothing);
  });

  testWidgets('Daily source buttons navigate with the report date', (
    tester,
  ) async {
    final reports = FakeAiReportRepository(
      reports: [
        buildAiReport(
          id: 'daily-navigation',
          reportType: AiReportType.dailyInsight,
          targetDate: '2026-07-16',
        ),
      ],
    );
    final router = GoRouter(
      initialLocation: '/reports/daily-navigation',
      routes: [
        GoRoute(
          path: '/reports/:reportId',
          builder: (context, state) => AiReportDetailPage(
            reportId: state.pathParameters['reportId'] ?? '',
          ),
        ),
        GoRoute(
          path: RoutePaths.todayHistory,
          builder: (context, state) => Scaffold(
            body: Text(
              'Today target ${state.uri.queryParameters['date']}',
              key: const ValueKey('todayExactDateDestination'),
            ),
          ),
        ),
        GoRoute(
          path: RoutePaths.journal,
          builder: (context, state) => Scaffold(
            body: Text(
              'Journal target ${state.uri.queryParameters['date']}',
              key: const ValueKey('journalExactDateDestination'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiReportRepositoryProvider.overrideWithValue(reports),
          aiCoachInputAssemblerProvider.overrideWithValue(
            FakeAiCoachInputAssembler(),
          ),
          aiGenerationRequestBindingStoreProvider.overrideWithValue(
            FakeAiGenerationRequestBindingStore(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final todayButton = find.byKey(
      const ValueKey('openDailySourceTodayButton'),
    );
    await _tapAfterScrolling(tester, todayButton);
    await tester.pumpAndSettle();
    expect(find.text('Today target 2026-07-16'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    final journalButton = find.byKey(
      const ValueKey('openDailySourceJournalButton'),
    );
    await _tapAfterScrolling(tester, journalButton);
    await tester.pumpAndSettle();
    expect(find.text('Journal target 2026-07-16'), findsOneWidget);
  });

  testWidgets('Weekly detail does not expose Daily source buttons', (
    tester,
  ) async {
    final reports = FakeAiReportRepository(
      reports: [buildAiReport(id: 'weekly-detail')],
    );
    await _pumpDetail(tester, reports, 'weekly-detail');

    expect(
      find.byKey(const ValueKey('openDailySourceTodayButton')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('openDailySourceJournalButton')),
      findsNothing,
    );
  });

  testWidgets(
    'detail soft delete returns to history without touching other reports',
    (tester) async {
      final untouched = buildAiReport(id: 'untouched');
      final reports = FakeAiReportRepository(
        reports: [
          buildAiReport(id: 'delete-detail'),
          untouched,
        ],
      );
      final router = GoRouter(
        initialLocation: '/history/reports/delete-detail',
        routes: [
          GoRoute(
            path: '/history',
            builder: (context, state) => const Scaffold(
              key: ValueKey('historyDestination'),
              body: Text('History destination'),
            ),
            routes: [
              GoRoute(
                path: 'reports/:reportId',
                builder: (context, state) => AiReportDetailPage(
                  reportId: state.pathParameters['reportId'] ?? '',
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiReportRepositoryProvider.overrideWithValue(reports),
            aiGenerationRequestBindingStoreProvider.overrideWithValue(
              FakeAiGenerationRequestBindingStore(),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final deleteButton = find.byKey(
        const ValueKey('deleteAiReportDetailButton'),
      );
      await _tapAfterScrolling(tester, deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('confirmAiReportDeleteButton')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('historyDestination')), findsOneWidget);
      expect(reports.lastDeletedId, 'delete-detail');
      expect(reports.reports.single, same(untouched));
    },
  );

  testWidgets(
    'responsive layouts avoid overflow at target widths and 2x text',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final width in [320.0, 360.0, 840.0, 1200.0]) {
        await tester.binding.setSurfaceSize(Size(width, 900));
        await _pumpAiCoach(
          tester,
          consent: _enabledConsent(),
          assembler: FakeAiCoachInputAssembler(),
          reports: FakeAiReportRepository(),
          textScale: 2,
        );
        expect(find.byKey(const ValueKey('aiCoachPage')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'width $width');
      }
    },
  );

  testWidgets('pending recovery controls fit a narrow history view', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 720));
    await _pumpAiCoach(
      tester,
      consent: _enabledConsent(),
      assembler: FakeAiCoachInputAssembler(),
      reports: FakeAiReportRepository(
        reports: [buildAiReport(id: 'pending', status: AiReportStatus.pending)],
      ),
      textScale: 2,
    );
    await tester.tap(find.widgetWithText(Tab, '本地报告'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('checkAiRequestStatus-pending')),
      100,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('aiReportHistoryList')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('checkAiRequestStatus-pending')),
      findsOneWidget,
    );
  });

  testWidgets('not found requires confirmation before marking pending failed', (
    tester,
  ) async {
    final gateway = FakeAiGenerationGateway()
      ..statusResult = const AiRemoteRequestResult(
        status: AiRemoteRequestStatus.notFound,
        requestId: 'pending',
        inputHash:
            '12345678aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa87654321',
        reportType: 'weekly_report',
        promptVersion: 'weekly-report-v1',
      );
    final bindings = FakeAiGenerationRequestBindingStore();
    bindings.values['pending'] = const AiGenerationRequestBinding(
      localReportId: 'pending',
      requestId: 'pending',
      normalizedEndpoint: 'http://127.0.0.1:8000',
      cloudUserId: 'user',
      inputHash:
          '12345678aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa87654321',
      reportType: 'weekly_report',
      promptVersion: 'weekly-report-v1',
      createdAt: 1,
    );
    final reports = FakeAiReportRepository(
      reports: [buildAiReport(id: 'pending', status: AiReportStatus.pending)],
    );
    await _pumpAiCoach(
      tester,
      consent: _enabledConsent(),
      assembler: FakeAiCoachInputAssembler(),
      reports: reports,
      gateway: gateway,
      bindings: bindings,
    );

    await tester.tap(find.widgetWithText(Tab, '本地报告'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('checkAiRequestStatus-pending')),
    );
    await tester.pumpAndSettle();
    final markFailed = find.byKey(
      const ValueKey('markServerNotFoundFailed-pending'),
    );
    expect(markFailed, findsOneWidget);

    await _tapAfterScrolling(tester, markFailed);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(reports.reports.single.status, AiReportStatus.pending);

    await _tapAfterScrolling(tester, markFailed);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmServerNotFoundButton')));
    await tester.pumpAndSettle();
    expect(reports.reports.single.status, AiReportStatus.failed);
    expect(reports.lastFailureCode, 'server_state_not_found');
    expect(bindings.values, isEmpty);
    expect(gateway.statusCalls, 1);
    expect(gateway.generationCalls, 0);
  });
}

FakeAiConsentRepository _enabledConsent() {
  return FakeAiConsentRepository(
    authorization: AiDataAuthorization(enabled: true, consentAt: 1),
  );
}

Future<void> _pumpAiCoach(
  WidgetTester tester, {
  required FakeAiConsentRepository consent,
  required FakeAiCoachInputAssembler assembler,
  required FakeAiReportRepository reports,
  GoRouter? router,
  double textScale = 1,
  FakeAiGenerationGateway? gateway,
  FakeAiGenerationRequestBindingStore? bindings,
}) async {
  final child = router == null
      ? MaterialApp(home: const AiCoachPage(), builder: _scaled(textScale))
      : MaterialApp.router(routerConfig: router, builder: _scaled(textScale));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiConsentRepositoryProvider.overrideWithValue(consent),
        aiCoachInputAssemblerProvider.overrideWithValue(assembler),
        aiReportRepositoryProvider.overrideWithValue(reports),
        aiGenerationRequestBindingStoreProvider.overrideWithValue(
          bindings ?? FakeAiGenerationRequestBindingStore(),
        ),
        aiGenerationGatewayProvider.overrideWithValue(
          gateway ?? FakeAiGenerationGateway(),
        ),
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
      child: child,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpDetail(
  WidgetTester tester,
  FakeAiReportRepository reports,
  String reportId,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiReportRepositoryProvider.overrideWithValue(reports),
        aiCoachInputAssemblerProvider.overrideWithValue(
          FakeAiCoachInputAssembler(),
        ),
        aiGenerationRequestBindingStoreProvider.overrideWithValue(
          FakeAiGenerationRequestBindingStore(),
        ),
      ],
      child: MaterialApp(home: AiReportDetailPage(reportId: reportId)),
    ),
  );
  await tester.pumpAndSettle();
}

TransitionBuilder _scaled(double scale) {
  return (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  );
}

Future<void> _tapAfterScrolling(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}
