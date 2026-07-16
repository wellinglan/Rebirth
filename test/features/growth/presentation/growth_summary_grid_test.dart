import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/growth/domain/growth_snapshot.dart';
import 'package:rebirth/features/growth/presentation/widgets/growth_summary_grid.dart';

import '../growth_test_data.dart';

void main() {
  testWidgets('renders all seven objective summary metrics', (tester) async {
    final snapshot = growthTestSnapshot(
      dataForDay: (index, date) => switch (index) {
        0 => const GrowthDayTestData(
          researchMinutes: 65,
          learningMinutes: 0,
          exerciseMinutes: 30,
          sleepMinutes: 420,
          moodScore: 3,
          energyScore: 4,
          journalRecorded: true,
          journalCompleted: true,
        ),
        1 => const GrowthDayTestData(
          researchMinutes: 55,
          learningMinutes: 60,
          exerciseMinutes: 0,
          sleepMinutes: 480,
          moodScore: 4,
          energyScore: 5,
          journalRecorded: true,
        ),
        _ => const GrowthDayTestData(),
      },
    );

    await _pumpSummary(tester, snapshot);

    expect(find.text('科研总时长'), findsOneWidget);
    expect(find.text('2 小时'), findsOneWidget);
    expect(find.text('学习总时长'), findsOneWidget);
    expect(find.text('1 小时'), findsOneWidget);
    expect(find.text('运动总时长'), findsOneWidget);
    expect(find.text('30 分钟'), findsOneWidget);
    expect(find.text('平均睡眠'), findsOneWidget);
    expect(find.text('7 小时 30 分钟'), findsOneWidget);
    expect(find.text('平均 Mood'), findsOneWidget);
    expect(find.text('3.5 / 5'), findsOneWidget);
    expect(find.text('平均 Energy'), findsOneWidget);
    expect(find.text('4.5 / 5'), findsOneWidget);
    expect(find.text('2 / 7 天'), findsOneWidget);
  });

  testWidgets('distinguishes missing metrics from explicitly recorded zero', (
    tester,
  ) async {
    final snapshot = growthTestSnapshot(
      dataForDay: (index, date) => index == 0
          ? const GrowthDayTestData(researchMinutes: 0)
          : const GrowthDayTestData(),
    );
    await _pumpSummary(tester, snapshot);

    final research = find.byKey(const ValueKey('growthSummary_research'));
    final learning = find.byKey(const ValueKey('growthSummary_learning'));
    expect(
      find.descendant(of: research, matching: find.text('0 分钟')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: learning, matching: find.text('暂无数据')),
      findsOneWidget,
    );
  });

  testWidgets('summary grid has no overflow at 360px', (tester) async {
    await _pumpSummary(
      tester,
      growthTestSnapshot(
        dataForDay: (index, date) => const GrowthDayTestData(
          researchMinutes: 65,
          learningMinutes: 120,
          exerciseMinutes: 45,
          sleepMinutes: 450,
          moodScore: 4,
          energyScore: 3,
          journalRecorded: true,
        ),
      ),
      size: const Size(360, 1100),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Card), findsNWidgets(7));
  });
}

Future<void> _pumpSummary(
  WidgetTester tester,
  GrowthSnapshot snapshot, {
  Size size = const Size(840, 800),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: GrowthSummaryGrid(snapshot: snapshot),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
