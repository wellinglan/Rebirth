import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_report_detail_page.dart';
import 'package:rebirth/features/ai_reports/data/ai_report_export_providers.dart';
import 'package:rebirth/features/ai_reports/domain/ai_report_export.dart';
import 'package:rebirth/features/ai_reports/domain/ai_report_export_service.dart';
import 'package:rebirth/features/ai_reports/presentation/ai_report_library_page.dart';

import '../../ai_coach/ai_coach_test_support.dart';

void main() {
  testWidgets('library confirms and exports all reports with saving state', (
    tester,
  ) async {
    final completer = Completer<AiReportExportResult>();
    final service = _FakeExportService(allResult: completer.future);
    await _pump(
      tester,
      repository: FakeAiReportRepository(
        reports: [buildAiReport(id: 'report-a')],
      ),
      service: service,
      child: const AiReportLibraryPage(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('exportAllAiReportsButton')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('aiReportExportConfirmationDialog')),
      findsOneWidget,
    );
    expect(find.textContaining('敏感个人信息'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('confirmAiReportExportButton')));
    await tester.pump();
    expect(find.text('导出中...'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('exportAllAiReportsButton')),
          )
          .onPressed,
      isNull,
    );

    completer.complete(
      const AiReportExportResult(
        disposition: AiReportExportDisposition.saved,
        reportCount: 1,
      ),
    );
    await tester.pumpAndSettle();
    expect(service.allCalls, 1);
    expect(find.text('AI 报告导出已保存'), findsOneWidget);
  });

  testWidgets('detail exports one report and cancellation keeps the page', (
    tester,
  ) async {
    final service = _FakeExportService(
      singleResult: Future.value(
        const AiReportExportResult(
          disposition: AiReportExportDisposition.cancelled,
          reportCount: 1,
        ),
      ),
    );
    await _pump(
      tester,
      repository: FakeAiReportRepository(
        reports: [buildAiReport(id: 'report-a')],
      ),
      service: service,
      child: const AiReportDetailPage(reportId: 'report-a'),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('exportAiReportDetailButton')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('exportAiReportDetailButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmAiReportExportButton')));
    await tester.pumpAndSettle();

    expect(service.singleCalls, 1);
    expect(find.byKey(const ValueKey('aiReportDetailPage')), findsOneWidget);
    expect(find.textContaining('已取消导出'), findsOneWidget);
  });

  testWidgets('failure keeps content visible and allows retry', (tester) async {
    final service = _FakeExportService(
      queuedAllResults: [
        () => Future.error(StateError('private path')),
        () => Future.value(
          const AiReportExportResult(
            disposition: AiReportExportDisposition.saved,
            reportCount: 1,
          ),
        ),
      ],
    );
    await _pump(
      tester,
      repository: FakeAiReportRepository(
        reports: [buildAiReport(id: 'report-a')],
      ),
      service: service,
      child: const AiReportLibraryPage(),
    );
    await tester.pumpAndSettle();

    await _confirmAllExport(tester);
    expect(find.textContaining('导出失败'), findsOneWidget);
    expect(find.text('AI 报告'), findsOneWidget);

    await _confirmAllExport(tester);
    expect(service.allCalls, 2);
    expect(find.text('AI 报告导出已保存'), findsOneWidget);
  });

  testWidgets('320px and TextScaler 2.0 keep export controls usable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 760);
    addTearDown(tester.view.reset);
    await _pump(
      tester,
      repository: FakeAiReportRepository(
        reports: [buildAiReport(id: 'report-a')],
      ),
      service: _FakeExportService(),
      textScaler: const TextScaler.linear(2),
      child: const AiReportLibraryPage(),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('exportAllAiReportsButton')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('exportAllAiReportsButton')));
    await tester.pumpAndSettle();
    expect(find.text('选择保存位置'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('aiReportExportConfirmationDialog')),
      findsNothing,
    );
  });

  testWidgets('keyboard activates the library export action', (tester) async {
    await _pump(
      tester,
      repository: FakeAiReportRepository(
        reports: [buildAiReport(id: 'report-a')],
      ),
      service: _FakeExportService(),
      child: const AiReportLibraryPage(),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('exportAllAiReportsButton'));
    final focusNode = tester.widget<OutlinedButton>(button).focusNode!;
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('aiReportExportConfirmationDialog')),
      findsOneWidget,
    );
  });
}

Future<void> _confirmAllExport(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('exportAllAiReportsButton')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('confirmAiReportExportButton')));
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  required FakeAiReportRepository repository,
  required AiReportExportService service,
  required Widget child,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiReportRepositoryProvider.overrideWithValue(repository),
        aiReportExportServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: child,
      ),
    ),
  );
}

final class _FakeExportService implements AiReportExportService {
  _FakeExportService({
    Future<AiReportExportResult>? singleResult,
    Future<AiReportExportResult>? allResult,
    List<Future<AiReportExportResult> Function()> queuedAllResults = const [],
  }) : singleResult =
           singleResult ??
           Future.value(
             const AiReportExportResult(
               disposition: AiReportExportDisposition.saved,
               reportCount: 1,
             ),
           ),
       allResult =
           allResult ??
           Future.value(
             const AiReportExportResult(
               disposition: AiReportExportDisposition.saved,
               reportCount: 1,
             ),
           ),
       queuedAllResults = [...queuedAllResults];

  final Future<AiReportExportResult> singleResult;
  final Future<AiReportExportResult> allResult;
  final List<Future<AiReportExportResult> Function()> queuedAllResults;
  int singleCalls = 0;
  int allCalls = 0;

  @override
  Future<AiReportExportResult> exportReport(String reportId) {
    singleCalls += 1;
    return singleResult;
  }

  @override
  Future<AiReportExportResult> exportAllReports() {
    allCalls += 1;
    return queuedAllResults.isEmpty
        ? allResult
        : queuedAllResults.removeAt(0)();
  }
}
