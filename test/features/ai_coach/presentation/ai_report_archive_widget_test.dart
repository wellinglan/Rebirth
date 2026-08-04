import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_report_detail_page.dart';

import '../ai_coach_test_support.dart';

void main() {
  testWidgets('completed report archives without hiding its content', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final reports = FakeAiReportRepository(
      reports: [buildAiReport(id: 'archive-detail')],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [aiReportRepositoryProvider.overrideWithValue(reports)],
        child: const MaterialApp(
          home: AiReportDetailPage(reportId: 'archive-detail'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('archiveAiReportDetailButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('aiReportArchiveDialog')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('confirmAiReportArchiveButton')),
    );
    await tester.pumpAndSettle();

    expect(reports.lastArchivedId, 'archive-detail');
    expect(reports.reports.single.status, AiReportStatus.archived);
    expect(reports.reports.single.reportContent, isNotNull);
    expect(
      find.byKey(const ValueKey('aiReportArchivedMessage')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('archiveAiReportDetailButton')),
      findsNothing,
    );
  });
}
