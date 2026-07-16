import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/growth/domain/growth_day_snapshot.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';
import 'package:rebirth/features/growth/presentation/widgets/growth_daily_details.dart';

import '../growth_test_data.dart';

void main() {
  testWidgets('daily details are collapsed by default', (tester) async {
    await _pumpDetails(tester, growthTestSnapshot().days);

    expect(find.byKey(const ValueKey('growthDailyDetails')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('growthDailyDetailsContent')),
      findsNothing,
    );
    expect(_detailRows(), findsNothing);
  });

  testWidgets('seven-day details expand in ascending date order', (
    tester,
  ) async {
    await _pumpDetails(tester, growthTestSnapshot().days);

    await tester.tap(find.byKey(const ValueKey('growthDailyDetailsToggle')));
    await tester.pumpAndSettle();

    expect(_detailRows(), findsNWidgets(7));
    expect(find.text('2026年7月10日'), findsOneWidget);
    expect(find.text('2026年7月16日'), findsOneWidget);
    final first = tester.getTopLeft(find.text('2026年7月10日')).dy;
    final last = tester.getTopLeft(find.text('2026年7月16日')).dy;
    expect(first, lessThan(last));
  });

  testWidgets('missing, zero, and duration values stay distinct', (
    tester,
  ) async {
    final snapshot = growthTestSnapshot(
      dataForDay: (index, date) => switch (index) {
        0 => const GrowthDayTestData(researchMinutes: null),
        1 => const GrowthDayTestData(researchMinutes: 0),
        2 => const GrowthDayTestData(researchMinutes: 65),
        _ => const GrowthDayTestData(),
      },
    );
    await _pumpDetails(tester, snapshot.days);

    await tester.tap(find.byKey(const ValueKey('growthDailyDetailsToggle')));
    await tester.pumpAndSettle();

    expect(find.text('科研：未记录'), findsWidgets);
    expect(find.text('科研：0 分钟'), findsOneWidget);
    expect(find.text('科研：1 小时 5 分钟'), findsOneWidget);
  });

  testWidgets('scores and all Journal states use factual labels', (
    tester,
  ) async {
    final snapshot = growthTestSnapshot(
      dataForDay: (index, date) => switch (index) {
        0 => const GrowthDayTestData(moodScore: 3, energyScore: 4),
        1 => const GrowthDayTestData(journalRecorded: true),
        2 => const GrowthDayTestData(
          journalRecorded: true,
          journalCompleted: true,
        ),
        _ => const GrowthDayTestData(),
      },
    );
    await _pumpDetails(tester, snapshot.days);

    await tester.tap(find.byKey(const ValueKey('growthDailyDetailsToggle')));
    await tester.pumpAndSettle();

    expect(find.text('Mood：3 / 5'), findsOneWidget);
    expect(find.text('Energy：4 / 5'), findsOneWidget);
    expect(find.text('Journal：未记录'), findsWidgets);
    expect(find.text('Journal：已记录，未完成'), findsOneWidget);
    expect(find.text('Journal：已完成'), findsOneWidget);
  });

  testWidgets('each date exposes one complete read-only semantic description', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final snapshot = growthTestSnapshot(
      dataForDay: (index, date) => index == 0
          ? const GrowthDayTestData(
              researchMinutes: 0,
              learningMinutes: 65,
              sleepMinutes: 420,
              exerciseMinutes: null,
              moodScore: 3,
              energyScore: 4,
              journalRecorded: true,
            )
          : const GrowthDayTestData(),
    );
    await _pumpDetails(tester, snapshot.days);

    expect(find.bySemanticsLabel('每日数据明细'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('growthDailyDetailsToggle')));
    await tester.pumpAndSettle();

    final detailsSemantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == '每日数据明细',
      ),
    );
    expect(detailsSemantics.properties.expanded, isTrue);
    expect(detailsSemantics.properties.value, '已展开');
    expect(
      find.bySemanticsLabel(
        '2026年7月10日；科研：0 分钟；学习：1 小时 5 分钟；睡眠：7 小时；'
        '运动：未记录；Mood：3 / 5；Energy：4 / 5；Journal：已记录，未完成',
      ),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    semantics.dispose();
  });

  testWidgets('thirty-day details build without nested scrolling', (
    tester,
  ) async {
    final snapshot = growthTestSnapshot(period: GrowthPeriod.thirtyDays);
    await _pumpDetails(tester, snapshot.days, size: const Size(320, 700));

    await tester.tap(find.byKey(const ValueKey('growthDailyDetailsToggle')));
    await tester.pumpAndSettle();

    expect(_detailRows(), findsNWidgets(30));
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(DataTable), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Finder _detailRows() {
  return find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith(
          'growthDailyDetail_',
        ),
  );
}

Future<void> _pumpDetails(
  WidgetTester tester,
  List<GrowthDaySnapshot> days, {
  Size size = const Size(700, 900),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: GrowthDailyDetails(days: days),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
