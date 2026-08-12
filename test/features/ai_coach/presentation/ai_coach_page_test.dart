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
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_request_binding.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';
import 'package:rebirth/features/ai_coach/domain/ai_usage_snapshot.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_weekly_report_page.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_report_detail_page.dart';
import 'package:rebirth/features/ai_reports/presentation/ai_report_library_page.dart';
import 'package:rebirth/features/settings/presentation/ai_consent_settings_page.dart';

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
    expect(find.textContaining('使用 AI 教练前'), findsOneWidget);
    expect(find.textContaining('最终确认生成前'), findsOneWidget);
    expect(assembler.buildCalls, 0);
    expect(consent.grantCalls, 0);
  });

  testWidgets(
    'consent gate opens consent settings and grant unlocks AI Coach',
    (tester) async {
      final consent = FakeAiConsentRepository(
        authorization: const AiDataAuthorization.disabled(),
      );
      final router = GoRouter(
        initialLocation: RoutePaths.aiCoach,
        routes: [
          GoRoute(
            path: RoutePaths.aiCoach,
            builder: (context, state) => const AiWeeklyReportPage(),
          ),
          GoRoute(
            path: RoutePaths.settingsAiConsent,
            builder: (context, state) => const AiConsentSettingsPage(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await _pumpAiCoach(
        tester,
        consent: consent,
        assembler: FakeAiCoachInputAssembler(),
        reports: FakeAiReportRepository(),
        router: router,
      );

      await tester.tap(
        find.byKey(const ValueKey('openAiConsentSettingsButton')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('aiConsentSettingsPage')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('settingsPage')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('enableAiDataSharingButton')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('confirmAiDataConsentButton')),
      );
      await tester.pumpAndSettle();
      expect(find.text('已启用'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('aiConsentGate')), findsNothing);
      expect(
        find.byKey(const ValueKey('buildAiPreviewButton')),
        findsOneWidget,
      );
      expect(consent.grantCalls, 1);
    },
  );

  testWidgets('revoking consent restores the AI Coach consent gate', (
    tester,
  ) async {
    final consent = _enabledConsent();
    final router = GoRouter(
      initialLocation: RoutePaths.settingsAiConsent,
      routes: [
        GoRoute(
          path: RoutePaths.aiCoach,
          builder: (context, state) => const AiWeeklyReportPage(),
        ),
        GoRoute(
          path: RoutePaths.settingsAiConsent,
          builder: (context, state) => const AiConsentSettingsPage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await _pumpAiCoach(
      tester,
      consent: consent,
      assembler: FakeAiCoachInputAssembler(),
      reports: FakeAiReportRepository(),
      router: router,
    );

    await tester.tap(find.byKey(const ValueKey('revokeAiDataSharingButton')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirmRevokeAiDataConsentButton')),
    );
    await tester.pumpAndSettle();
    router.go(RoutePaths.aiCoach);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('aiConsentGate')), findsOneWidget);
    expect(consent.revokeCalls, 1);
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
    expect(find.text('请至少选择一种数据。'), findsOneWidget);
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
            builder: (context, state) => const AiWeeklyReportPage(),
          ),
          GoRoute(
            path: '${RoutePaths.aiReports}/:reportId',
            builder: (context, state) => AiReportDetailPage(
              reportId: state.pathParameters['reportId'] ?? '',
            ),
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
      expect(find.text('12345678…87654321'), findsNothing);
      expect(find.text('Prompt Version'), findsNothing);
      expect(find.text('Input Hash'), findsNothing);
      await _tapAfterScrolling(
        tester,
        find.byKey(const ValueKey('aiPreviewTechnicalDetails')),
      );
      await tester.pumpAndSettle();
      expect(find.text('12345678…87654321'), findsOneWidget);
      expect(find.text('提示模板版本'), findsOneWidget);
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

  testWidgets('weekly flow has no local-report tab or duplicate report list', (
    tester,
  ) async {
    final reports = FakeAiReportRepository(
      reports: [buildAiReport(id: 'completed')],
    );
    await _pumpAiCoach(
      tester,
      consent: _enabledConsent(),
      assembler: FakeAiCoachInputAssembler(),
      reports: reports,
    );

    expect(find.byType(Tab), findsNothing);
    expect(find.byKey(const ValueKey('aiReportLibraryList')), findsNothing);
    expect(find.byKey(const ValueKey('aiWeeklyReportPage')), findsOneWidget);
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
      expect(find.textContaining('Provider'), findsNothing);
      expect(find.textContaining('Model'), findsNothing);
      expect(find.textContaining('输入快照'), findsNothing);
      expect(find.textContaining('Prompt Version'), findsNothing);
      expect(find.textContaining('Input Hash'), findsNothing);
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

  testWidgets('disabled provider has an explicit UI state', (tester) async {
    final gateway = FakeAiGenerationGateway(
      capabilities: AiGenerationCapabilities(
        enabled: false,
        provider: 'disabled',
        providerLabel: 'Disabled',
        model: null,
        supportedReportTypes: const ['weekly_report'],
        promptVersions: const ['weekly-report-v1'],
        inputSchemaVersion: 1,
        outputSchemaVersion: 1,
        streaming: false,
        responseStorageRequested: false,
      ),
    );
    await _pumpAiCoach(
      tester,
      consent: _enabledConsent(),
      assembler: FakeAiCoachInputAssembler(),
      reports: FakeAiReportRepository(),
      gateway: gateway,
    );

    await _tapAfterScrolling(
      tester,
      find.byKey(const ValueKey('aiScope-growth_summary')),
    );
    await _tapAfterScrolling(
      tester,
      find.byKey(const ValueKey('buildAiPreviewButton')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('AI 服务当前暂不可用'), findsOneWidget);
    expect(gateway.generationCalls, 0);
  });

  testWidgets('provider timeout keeps preview and exposes manual retry', (
    tester,
  ) async {
    final gateway = FakeAiGenerationGateway()
      ..generationError = const AiGenerationException(
        AiReportFailureCode.providerTimeout,
      );
    final reports = FakeAiReportRepository();
    final assembler = FakeAiCoachInputAssembler(
      bundle: buildAiBundle(
        scopes: {AiDataScope.growthSummary},
        sourceCount: 0,
      ),
    );
    await _pumpAiCoach(
      tester,
      consent: _enabledConsent(),
      assembler: assembler,
      reports: reports,
      gateway: gateway,
    );
    await _buildGrowthPreview(tester);

    await _submitWeeklyGeneration(tester);

    expect(assembler.bundle.sources, isEmpty);
    expect(find.byKey(const ValueKey('aiRequestPreview')), findsOneWidget);
    expect(find.textContaining('本次生成等待超时'), findsOneWidget);
    expect(find.textContaining('不会自动重试'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('retryAiGenerationButton')),
      findsOneWidget,
    );
    expect(reports.lastFailureCode, 'provider_timeout');
    expect(gateway.generationCalls, 1);
  });

  testWidgets(
    'provider unavailable keeps preview and explicit retry can succeed',
    (tester) async {
      final gateway = FakeAiGenerationGateway()
        ..generationError = const AiGenerationException(
          AiReportFailureCode.providerUnavailable,
        );
      final reports = FakeAiReportRepository();
      final assembler = FakeAiCoachInputAssembler(
        bundle: buildAiBundle(scopes: {AiDataScope.growthSummary}),
      );
      final router = GoRouter(
        initialLocation: RoutePaths.aiCoach,
        routes: [
          GoRoute(
            path: RoutePaths.aiCoach,
            builder: (context, state) => const AiWeeklyReportPage(),
          ),
          GoRoute(
            path: '${RoutePaths.aiReports}/:reportId',
            builder: (context, state) => AiReportDetailPage(
              reportId: state.pathParameters['reportId'] ?? '',
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await _pumpAiCoach(
        tester,
        consent: _enabledConsent(),
        assembler: assembler,
        reports: reports,
        gateway: gateway,
        router: router,
      );
      await _buildGrowthPreview(tester);
      await _submitWeeklyGeneration(tester);

      expect(find.byKey(const ValueKey('aiRequestPreview')), findsOneWidget);
      expect(find.textContaining('每周回顾暂时无法生成'), findsOneWidget);
      expect(reports.lastFailureCode, 'provider_unavailable');

      gateway.generationError = null;
      await _tapAfterScrolling(
        tester,
        find.byKey(const ValueKey('retryAiGenerationButton')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('aiGenerationConfirmationDialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('confirmAiGenerationButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('aiReportDetailPage')), findsOneWidget);
      expect(gateway.generationCalls, 2);
      expect(reports.markFailedCalls, 1);
      expect(reports.markCompletedCalls, 1);
    },
  );

  testWidgets(
    'network uncertainty opens pending history without another generation',
    (tester) async {
      final gateway = FakeAiGenerationGateway()
        ..generationError = const AiGenerationException(
          AiReportFailureCode.networkOutcomeUnknown,
        );
      final reports = FakeAiReportRepository();
      final assembler = FakeAiCoachInputAssembler(
        bundle: buildAiBundle(scopes: {AiDataScope.growthSummary}),
      );
      final router = GoRouter(
        initialLocation: RoutePaths.aiCoach,
        routes: [
          GoRoute(
            path: RoutePaths.aiCoach,
            builder: (_, _) => const AiWeeklyReportPage(),
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
      addTearDown(router.dispose);
      await _pumpAiCoach(
        tester,
        consent: _enabledConsent(),
        assembler: assembler,
        reports: reports,
        gateway: gateway,
        router: router,
      );
      await _buildGrowthPreview(tester);
      await _submitWeeklyGeneration(tester);

      expect(find.byKey(const ValueKey('aiRequestPreview')), findsOneWidget);
      expect(find.textContaining('上次生成仍在处理中'), findsWidgets);
      expect(reports.reports.single.status, AiReportStatus.pending);
      expect(gateway.generationCalls, 1);

      await _tapAfterScrolling(
        tester,
        find.byKey(const ValueKey('openPendingAiReportsButton')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('aiReportLibraryCard-pending-1')),
        findsOneWidget,
      );

      gateway.statusError = const AiGenerationException(
        AiReportFailureCode.networkOutcomeUnknown,
      );
      await tester.tap(
        find.byKey(const ValueKey('aiReportLibraryCard-pending-1')),
      );
      await tester.pumpAndSettle();
      await _tapAfterScrolling(
        tester,
        find.byKey(const ValueKey('checkAiRequestStatusDetailButton')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('不会自动重新生成'), findsOneWidget);
      expect(gateway.statusCalls, 1);
      expect(gateway.generationCalls, 1);
      expect(reports.reports.single.status, AiReportStatus.pending);
    },
  );

  testWidgets(
    'current usage is visible and a reached limit disables generate',
    (tester) async {
      final gateway = FakeAiGenerationGateway(
        usage: const AiUsageSnapshot(
          availability: AiUsageAvailability.limitReached,
          enabled: true,
          dailyLimit: 10,
          used: 10,
          remaining: 0,
          resetsAtUtcMilliseconds: 1785628800000,
        ),
      );
      await _pumpAiCoach(
        tester,
        consent: _enabledConsent(),
        assembler: FakeAiCoachInputAssembler(),
        reports: FakeAiReportRepository(),
        gateway: gateway,
      );
      await _buildGrowthPreview(tester);

      expect(find.byKey(const ValueKey('aiUsageSummary')), findsOneWidget);
      final generate = tester.widget<FilledButton>(
        find.byKey(const ValueKey('generateWeeklyReportButton')),
      );
      expect(generate.onPressed, isNull);
      expect(gateway.usageCalls, 1);
      expect(gateway.generationCalls, 0);
    },
  );

  testWidgets('usage failure has a safe unknown fallback', (tester) async {
    final gateway = FakeAiGenerationGateway()
      ..usageError = StateError('offline');
    await _pumpAiCoach(
      tester,
      consent: _enabledConsent(),
      assembler: FakeAiCoachInputAssembler(),
      reports: FakeAiReportRepository(),
      gateway: gateway,
    );
    await _buildGrowthPreview(tester);

    expect(find.byKey(const ValueKey('aiUsageUnknown')), findsOneWidget);
    final generate = tester.widget<FilledButton>(
      find.byKey(const ValueKey('generateWeeklyReportButton')),
    );
    expect(generate.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('generation rechecks usage before opening confirmation', (
    tester,
  ) async {
    final gateway = FakeAiGenerationGateway();
    await _pumpAiCoach(
      tester,
      consent: _enabledConsent(),
      assembler: FakeAiCoachInputAssembler(),
      reports: FakeAiReportRepository(),
      gateway: gateway,
    );
    await _buildGrowthPreview(tester);
    gateway.usage = const AiUsageSnapshot(
      availability: AiUsageAvailability.limitReached,
      enabled: true,
      dailyLimit: 10,
      used: 10,
      remaining: 0,
      resetsAtUtcMilliseconds: 1785628800000,
    );

    await _tapAfterScrolling(
      tester,
      find.byKey(const ValueKey('generateWeeklyReportButton')),
    );
    await tester.pumpAndSettle();

    expect(gateway.usageCalls, 2);
    expect(gateway.generationCalls, 0);
    expect(
      find.byKey(const ValueKey('aiGenerationConfirmationDialog')),
      findsNothing,
    );
  });

  testWidgets('usage limit failure remains readable at 320px and 2x text', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 800));
    final gateway = FakeAiGenerationGateway()
      ..capabilitiesError = const AiGenerationException(
        AiReportFailureCode.usageLimitReached,
      );
    await _pumpAiCoach(
      tester,
      consent: _enabledConsent(),
      assembler: FakeAiCoachInputAssembler(),
      reports: FakeAiReportRepository(),
      gateway: gateway,
      textScale: 2,
    );

    await _tapAfterScrolling(
      tester,
      find.byKey(const ValueKey('aiScope-growth_summary')),
    );
    await _tapAfterScrolling(
      tester,
      find.byKey(const ValueKey('buildAiPreviewButton')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('今天的 AI 次数已用完'), findsOneWidget);
    expect(gateway.generationCalls, 0);
    expect(tester.takeException(), isNull);
  });

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
        expect(
          find.byKey(const ValueKey('aiWeeklyReportPage')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: 'width $width');
      }
    },
  );

  testWidgets('weekly flow fits a narrow high-text viewport', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 720));
    await _pumpAiCoach(
      tester,
      consent: _enabledConsent(),
      assembler: FakeAiCoachInputAssembler(),
      reports: FakeAiReportRepository(),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('aiWeeklyReportPage')), findsOneWidget);
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
    final router = GoRouter(
      initialLocation: '/report',
      routes: [
        GoRoute(
          path: '/report',
          builder: (_, _) => const AiReportDetailPage(reportId: 'pending'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await _pumpAiCoach(
      tester,
      consent: _enabledConsent(),
      assembler: FakeAiCoachInputAssembler(),
      reports: reports,
      router: router,
      gateway: gateway,
      bindings: bindings,
    );

    await tester.tap(
      find.byKey(const ValueKey('checkAiRequestStatusDetailButton')),
    );
    await tester.pumpAndSettle();
    final markFailed = find.byKey(
      const ValueKey('markServerNotFoundFailedDetailButton'),
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
      ? MaterialApp(
          home: const AiWeeklyReportPage(),
          builder: _scaled(textScale),
        )
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

Future<void> _buildGrowthPreview(WidgetTester tester) async {
  await _tapAfterScrolling(
    tester,
    find.byKey(const ValueKey('aiScope-growth_summary')),
  );
  await _tapAfterScrolling(
    tester,
    find.byKey(const ValueKey('buildAiPreviewButton')),
  );
  await tester.pumpAndSettle();
}

Future<void> _submitWeeklyGeneration(WidgetTester tester) async {
  await _tapAfterScrolling(
    tester,
    find.byKey(const ValueKey('generateWeeklyReportButton')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('confirmAiGenerationButton')));
  await tester.pumpAndSettle();
}
