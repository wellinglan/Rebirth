import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_mode.dart';
import 'package:rebirth/features/ai_coach/domain/ai_input_source_ref.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_metadata.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_version.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_report_detail_page.dart';
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
    expect(repository.createPendingCalls, 0);
  });

  testWidgets('lists lifecycle and sync states with lightweight filters', (
    tester,
  ) async {
    final repository = FakeAiReportRepository(
      reports: [
        _report(
          id: 'completed',
          title: '完成报告',
          status: AiReportStatus.completed,
          syncStatus: 'synced',
        ),
        _report(
          id: 'archived',
          title: '归档报告',
          status: AiReportStatus.archived,
          syncStatus: 'pending',
        ),
        _report(
          id: 'failed',
          title: '失败报告',
          status: AiReportStatus.failed,
          syncStatus: 'conflict',
        ),
      ],
    );
    await _pump(tester, repository, const AiReportLibraryPage());
    await tester.pumpAndSettle();

    expect(find.text('完成报告'), findsOneWidget);
    expect(find.text('归档报告'), findsOneWidget);
    expect(find.text('失败报告'), findsOneWidget);
    expect(find.text('已同步'), findsOneWidget);
    expect(find.text('等待同步'), findsOneWidget);
    expect(find.text('存在冲突'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('aiReportLibraryFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已归档').last);
    await tester.pumpAndSettle();

    expect(find.text('归档报告'), findsOneWidget);
    expect(find.text('完成报告'), findsNothing);
    expect(find.text('失败报告'), findsNothing);
  });

  testWidgets('ordinary list hides private and internal report metadata', (
    tester,
  ) async {
    final repository = FakeAiReportRepository(
      reports: [
        _report(
          id: 'internal-report-id',
          title: '安全标题',
          status: AiReportStatus.completed,
          syncStatus: 'synced',
        ),
      ],
    );
    await _pump(tester, repository, const AiReportLibraryPage());
    await tester.pumpAndSettle();

    expect(find.text('安全标题'), findsOneWidget);
    for (final forbidden in const [
      'internal-report-id',
      'private-user-id',
      'private-hash',
      'private-provider',
      'private-model',
      'private report body',
      'Prompt',
      'API',
      'Token',
      'Secret',
    ]) {
      expect(find.textContaining(forbidden), findsNothing);
    }
  });

  testWidgets('detail reuses version history and archive lifecycle', (
    tester,
  ) async {
    final report = _report(
      id: 'versioned',
      title: '版本报告',
      status: AiReportStatus.completed,
      syncStatus: 'pending',
      versions: [_version(2, '第二版正文'), _version(1, '第一版正文')],
    );
    final repository = FakeAiReportRepository(reports: [report]);
    await _pump(
      tester,
      repository,
      const AiReportDetailPage(reportId: 'versioned'),
    );
    await tester.pumpAndSettle();

    expect(find.text('版本报告'), findsOneWidget);
    expect(find.text('v2 · 已完成'), findsOneWidget);
    expect(find.text('v1 · 已完成'), findsOneWidget);
    expect(find.text('第二版正文'), findsOneWidget);
    expect(find.text('第一版正文'), findsOneWidget);

    final archive = find.byKey(const ValueKey('archiveAiReportDetailButton'));
    await tester.ensureVisible(archive);
    await tester.pumpAndSettle();
    await tester.tap(archive);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirmAiReportArchiveButton')),
    );
    await tester.pumpAndSettle();

    expect(repository.reports.single.status, AiReportStatus.archived);
    expect(repository.reports.single.versions, hasLength(2));
    expect(
      find.byKey(const ValueKey('aiReportArchivedMessage')),
      findsOneWidget,
    );
  });

  testWidgets('sync and conflict actions open their canonical destinations', (
    tester,
  ) async {
    final repository = FakeAiReportRepository();
    final router = GoRouter(
      initialLocation: RoutePaths.aiReports,
      routes: [
        GoRoute(
          path: RoutePaths.aiReports,
          builder: (_, _) => const AiReportLibraryPage(),
        ),
        GoRoute(
          path: RoutePaths.syncCenter,
          builder: (_, _) => const Scaffold(body: Text('同步中心目标')),
        ),
        GoRoute(
          path: RoutePaths.syncConflicts,
          builder: (_, state) => Scaffold(
            body: Text('冲突目标 ${state.uri.queryParameters['module']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await _pumpRouter(tester, repository, router);

    await tester.tap(
      find.byKey(const ValueKey('openAiReportConflictCenterButton')),
    );
    await tester.pumpAndSettle();
    expect(find.text('冲突目标 module.ai_report'), findsOneWidget);

    router.go(RoutePaths.aiReports);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('openAiReportSyncCenterButton')),
    );
    await tester.pumpAndSettle();
    expect(find.text('同步中心目标'), findsOneWidget);
  });

  testWidgets('provider scope change does not retain another account reports', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeAiReportRepository(
        reports: [
          _report(
            id: 'account-a',
            title: '账号 A 报告',
            status: AiReportStatus.completed,
            syncStatus: 'synced',
          ),
        ],
      ),
      const AiReportLibraryPage(),
    );
    await tester.pumpAndSettle();
    expect(find.text('账号 A 报告'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await _pump(
      tester,
      FakeAiReportRepository(
        reports: [
          _report(
            id: 'account-b',
            title: '账号 B 报告',
            status: AiReportStatus.completed,
            syncStatus: 'synced',
          ),
        ],
      ),
      const AiReportLibraryPage(),
    );
    await tester.pumpAndSettle();

    expect(find.text('账号 A 报告'), findsNothing);
    expect(find.text('账号 B 报告'), findsOneWidget);
  });

  testWidgets('target widths and text scales remain free of overflow', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeAiReportRepository(
      reports: [
        _report(
          id: 'responsive',
          title: '响应式 AI 报告标题',
          status: AiReportStatus.completed,
          syncStatus: 'conflict',
        ),
      ],
    );

    for (final width in [320.0, 360.0, 412.0, 720.0, 840.0, 1200.0]) {
      for (final scale in [1.0, 2.0]) {
        await tester.binding.setSurfaceSize(Size(width, 900));
        await _pump(
          tester,
          repository,
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const AiReportLibraryPage(),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'width $width, scale $scale',
        );
      }
    }
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

Future<void> _pumpRouter(
  WidgetTester tester,
  FakeAiReportRepository repository,
  GoRouter router,
) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [aiReportRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(
        theme: ThemeData(useMaterial3: true),
        routerConfig: router,
      ),
    ),
  );
}

AiReport _report({
  required String id,
  required String title,
  required AiReportStatus status,
  required String syncStatus,
  List<AiReportVersion> versions = const [],
}) {
  final keepsBody =
      status == AiReportStatus.completed || status == AiReportStatus.archived;
  return AiReport(
    id: id,
    userId: 'private-user-id',
    reportType: AiReportType.weeklyReport,
    periodStartDate: '2026-07-24',
    periodEndDate: '2026-07-30',
    inputSources: const <AiInputSourceRef>[],
    selectedScopes: const <AiDataScope>{},
    inputHash: 'private-hash',
    promptVersion: 'private-prompt-version',
    provider: 'private-provider',
    model: 'private-model',
    generationMode: AiGenerationMode.manual,
    status: status,
    reportContent: keepsBody ? 'private report body' : null,
    structuredOutputJson: null,
    hasInputSnapshot: false,
    errorCode: status == AiReportStatus.failed ? 'request_failed' : null,
    requestedAt: 1,
    generatedAt: keepsBody ? 2 : null,
    createdAt: 1,
    updatedAt: 2,
    title: title,
    generationSource: 'fake',
    sensitivity: AiReportSensitivity.high,
    quality: AiReportQuality.unreviewed,
    currentVersion: versions.isEmpty && keepsBody ? 1 : versions.length,
    syncStatus: syncStatus,
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
