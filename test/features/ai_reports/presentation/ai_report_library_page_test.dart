import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_mode.dart';
import 'package:rebirth/features/ai_coach/domain/ai_input_source_ref.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_metadata.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_version.dart';
import 'package:rebirth/features/ai_reports/presentation/ai_report_library_detail_page.dart';
import 'package:rebirth/features/ai_reports/presentation/ai_report_library_page.dart';

import '../../ai_coach/ai_coach_test_support.dart';

void main() {
  testWidgets('shows loading and empty states without generating', (
    tester,
  ) async {
    final repository = _DelayedReportRepository();
    await _pump(tester, repository, const AiReportLibraryPage());

    expect(
      find.byKey(const ValueKey('aiReportLibraryLoading')),
      findsOneWidget,
    );

    repository.complete(const []);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('aiReportLibraryEmpty')), findsOneWidget);
    expect(find.textContaining('自动触发'), findsOneWidget);
  });

  testWidgets('shows completed and failed reports', (tester) async {
    final repository = FakeAiReportRepository(
      reports: [
        _report(id: 'completed', status: AiReportStatus.completed),
        _report(id: 'failed', status: AiReportStatus.failed),
      ],
    );
    await _pump(tester, repository, const AiReportLibraryPage());
    await tester.pumpAndSettle();

    expect(find.text('每周成长报告'), findsNWidgets(2));
    expect(find.textContaining('已完成 · v1'), findsOneWidget);
    expect(find.textContaining('失败'), findsOneWidget);
  });

  testWidgets('detail displays immutable version history without secrets', (
    tester,
  ) async {
    final report = _report(
      id: 'versioned',
      status: AiReportStatus.completed,
      versions: [_version(2, '第二版正文'), _version(1, '第一版正文')],
    );
    final repository = FakeAiReportRepository(reports: [report]);
    await _pump(
      tester,
      repository,
      const AiReportLibraryDetailPage(reportId: 'versioned'),
    );
    await tester.pumpAndSettle();

    expect(find.text('v2 · 已完成'), findsOneWidget);
    expect(find.text('v1 · 已完成'), findsOneWidget);
    expect(find.text('第二版正文'), findsOneWidget);
    expect(find.text('第一版正文'), findsOneWidget);
    expect(find.textContaining('API Key'), findsNothing);
    expect(find.textContaining('Token'), findsNothing);
    expect(find.textContaining('Prompt'), findsNothing);
    expect(find.textContaining('private-user-id'), findsNothing);
  });

  testWidgets('320px and text scaler 2 remain readable without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeAiReportRepository(
      reports: [_report(id: 'responsive', status: AiReportStatus.completed)],
    );
    await _pump(
      tester,
      repository,
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: AiReportLibraryPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('每周成长报告'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  FakeAiReportRepository repository,
  Widget child,
) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [aiReportRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(theme: ThemeData(useMaterial3: true), home: child),
    ),
  );
}

AiReport _report({
  required String id,
  required AiReportStatus status,
  List<AiReportVersion> versions = const [],
}) {
  return AiReport(
    id: id,
    userId: 'private-user-id',
    reportType: AiReportType.weeklyReport,
    periodStartDate: '2026-07-24',
    periodEndDate: '2026-07-30',
    inputSources: const <AiInputSourceRef>[],
    selectedScopes: const <AiDataScope>{},
    inputHash: 'private-hash',
    promptVersion: 'weekly-report-v1',
    provider: null,
    model: null,
    generationMode: AiGenerationMode.manual,
    status: status,
    reportContent: status == AiReportStatus.completed ? '最新正文' : null,
    structuredOutputJson: null,
    hasInputSnapshot: false,
    errorCode: status == AiReportStatus.failed ? 'request_failed' : null,
    requestedAt: 1,
    generatedAt: status == AiReportStatus.completed ? 2 : null,
    createdAt: 1,
    updatedAt: 2,
    title: '每周成长报告',
    generationSource: 'fake',
    sensitivity: AiReportSensitivity.high,
    quality: AiReportQuality.unreviewed,
    currentVersion: versions.isEmpty && status == AiReportStatus.completed
        ? 1
        : versions.length,
    versions: versions,
  );
}

AiReportVersion _version(int number, String content) {
  return AiReportVersion(
    id: 'version-$number',
    reportId: 'versioned',
    version: number,
    status: AiReportStatus.completed,
    generationSource: 'fake',
    modelMetadataJson: '{"model":"hidden"}',
    content: content,
    sensitivity: AiReportSensitivity.high,
    quality: AiReportQuality.unreviewed,
    errorCode: null,
    createdAt: number,
    completedAt: number,
  );
}

final class _DelayedReportRepository extends FakeAiReportRepository {
  _DelayedReportRepository() : super();

  final Completer<List<AiReport>> _completer = Completer<List<AiReport>>();

  void complete(List<AiReport> reports) => _completer.complete(reports);

  @override
  Future<List<AiReport>> listRecent({int limit = 20}) => _completer.future;
}
