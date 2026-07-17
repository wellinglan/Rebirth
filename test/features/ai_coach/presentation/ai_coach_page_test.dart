import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_authorization.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
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
      expect(find.textContaining('此请求尚未完成'), findsOneWidget);
      expect(find.textContaining('不提供继续处理按钮'), findsOneWidget);

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
          overrides: [aiReportRepositoryProvider.overrideWithValue(reports)],
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
        aiGenerationGatewayProvider.overrideWithValue(
          FakeAiGenerationGateway(),
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
      overrides: [aiReportRepositoryProvider.overrideWithValue(reports)],
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

Future<void> _tapAfterScrolling(
  WidgetTester tester,
  Finder finder,
) async {
  await Scrollable.ensureVisible(
    tester.element(finder),
    alignment: 0.5,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
}
