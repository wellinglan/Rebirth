import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';
import 'package:rebirth/features/growth/presentation/growth_presentation_mapper.dart';
import 'package:rebirth/features/growth/presentation/models/growth_chart_models.dart';
import 'package:rebirth/features/growth/presentation/widgets/journal_coverage_grid.dart';

import '../growth_test_data.dart';

void main() {
  testWidgets(
    'shows seven missing, draft, and completed date states with counts',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final snapshot = growthTestSnapshot(
        dataForDay: (index, date) => switch (index) {
          1 => const GrowthDayTestData(journalRecorded: true),
          2 => const GrowthDayTestData(
            journalRecorded: true,
            journalCompleted: true,
          ),
          _ => const GrowthDayTestData(),
        },
      );
      final data = const GrowthPresentationMapper().map(snapshot);
      await _pumpJournal(tester, data.journalDays, 2, 1);

      for (final day in data.journalDays) {
        expect(
          find.byKey(ValueKey('growthJournalDay_${day.date}')),
          findsOneWidget,
        );
      }
      expect(find.text('已记录 2 / 7 天 · 已完成 1 / 7 天'), findsOneWidget);
      expect(find.bySemanticsLabel('7月10日，未记录'), findsOneWidget);
      expect(find.bySemanticsLabel('7月11日，有内容，尚未完成'), findsOneWidget);
      expect(find.bySemanticsLabel('7月12日，有内容，已完成'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('thirty-day coverage wraps all date cells', (tester) async {
    final snapshot = growthTestSnapshot(
      period: GrowthPeriod.thirtyDays,
      dataForDay: (index, date) => GrowthDayTestData(
        journalRecorded: index.isEven,
        journalCompleted: index % 4 == 0,
      ),
    );
    final data = const GrowthPresentationMapper().map(snapshot);
    await _pumpJournal(
      tester,
      data.journalDays,
      snapshot.journalRecordedDays,
      snapshot.journalCompletedDays,
      size: const Size(360, 850),
    );

    for (final day in data.journalDays) {
      expect(
        find.byKey(ValueKey('growthJournalDay_${day.date}')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('coverage has no streak, flame, or reward language', (
    tester,
  ) async {
    final snapshot = growthTestSnapshot();
    final data = const GrowthPresentationMapper().map(snapshot);
    await _pumpJournal(tester, data.journalDays, 0, 0);

    expect(find.textContaining('连续'), findsNothing);
    expect(find.textContaining('奖励'), findsNothing);
    expect(find.byIcon(Icons.local_fire_department), findsNothing);
  });
}

Future<void> _pumpJournal(
  WidgetTester tester,
  List<GrowthJournalDay> days,
  int recorded,
  int completed, {
  Size size = const Size(700, 600),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: JournalCoverageGrid(
            days: days,
            recordedDays: recorded,
            completedDays: completed,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
