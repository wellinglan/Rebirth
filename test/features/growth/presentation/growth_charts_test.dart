import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';
import 'package:rebirth/features/growth/presentation/growth_presentation_mapper.dart';
import 'package:rebirth/features/growth/presentation/widgets/exercise_trend_chart.dart';
import 'package:rebirth/features/growth/presentation/widgets/focus_trend_chart.dart';
import 'package:rebirth/features/growth/presentation/widgets/mood_energy_chart.dart';
import 'package:rebirth/features/growth/presentation/widgets/sleep_trend_chart.dart';

import '../growth_test_data.dart';

void main() {
  testWidgets(
    'focus chart receives two seven-day series with null gaps and zero',
    (tester) async {
      final data = const GrowthPresentationMapper().map(
        growthTestSnapshot(
          dataForDay: (index, date) => switch (index) {
            0 => const GrowthDayTestData(
              researchMinutes: null,
              learningMinutes: 30,
            ),
            1 => const GrowthDayTestData(
              researchMinutes: 0,
              learningMinutes: null,
            ),
            _ => const GrowthDayTestData(),
          },
        ),
      );
      await _pumpChart(
        tester,
        FocusTrendChart(
          research: data.research,
          learning: data.learning,
          period: GrowthPeriod.sevenDays,
        ),
      );

      expect(find.text('专注投入'), findsOneWidget);
      expect(find.text('科研'), findsOneWidget);
      expect(find.text('学习'), findsOneWidget);
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData, hasLength(2));
      expect(chart.data.lineBarsData[0].spots, hasLength(7));
      expect(chart.data.lineBarsData[0].spots[0], FlSpot.nullSpot);
      expect(chart.data.lineBarsData[0].spots[1].y, 0);
      final missingTooltipItems = chart.data.lineTouchData.touchTooltipData
          .getTooltipItems([
            LineBarSpot(chart.data.lineBarsData[0], 0, const FlSpot(0, 0)),
          ]);
      expect(missingTooltipItems, [isNull]);
    },
  );

  testWidgets('thirty-day chart keeps thirty points while labels stay sparse', (
    tester,
  ) async {
    final data = const GrowthPresentationMapper().map(
      growthTestSnapshot(
        period: GrowthPeriod.thirtyDays,
        dataForDay: (index, date) => GrowthDayTestData(
          researchMinutes: index,
          learningMinutes: index * 2,
        ),
      ),
    );
    await _pumpChart(
      tester,
      FocusTrendChart(
        research: data.research,
        learning: data.learning,
        period: GrowthPeriod.thirtyDays,
      ),
      size: const Size(720, 520),
    );

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData[0].spots, hasLength(30));
    expect(chart.data.lineBarsData[1].spots, hasLength(30));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'fully missing series use local empty states instead of fake curves',
    (tester) async {
      final data = const GrowthPresentationMapper().map(growthTestSnapshot());

      await _pumpChart(
        tester,
        FocusTrendChart(
          research: data.research,
          learning: data.learning,
          period: GrowthPeriod.sevenDays,
        ),
      );
      expect(
        find.byKey(const ValueKey('growthFocusTrendEmpty')),
        findsOneWidget,
      );
      expect(find.byType(LineChart), findsNothing);

      await _pumpChart(
        tester,
        SleepTrendChart(sleep: data.sleep, period: GrowthPeriod.sevenDays),
      );
      expect(
        find.byKey(const ValueKey('growthSleepTrendEmpty')),
        findsOneWidget,
      );

      await _pumpChart(
        tester,
        ExerciseTrendChart(
          exercise: data.exercise,
          period: GrowthPeriod.sevenDays,
        ),
      );
      expect(
        find.byKey(const ValueKey('growthExerciseTrendEmpty')),
        findsOneWidget,
      );

      await _pumpChart(
        tester,
        MoodEnergyChart(
          mood: data.mood,
          energy: data.energy,
          period: GrowthPeriod.sevenDays,
        ),
      );
      expect(
        find.byKey(const ValueKey('growthMoodEnergyEmpty')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'explicit zero renders focus, sleep, and exercise at the baseline',
    (tester) async {
      final data = const GrowthPresentationMapper().map(
        growthTestSnapshot(
          dataForDay: (index, date) => index == 0
              ? const GrowthDayTestData(
                  researchMinutes: 0,
                  sleepMinutes: 0,
                  exerciseMinutes: 0,
                )
              : const GrowthDayTestData(),
        ),
      );

      await _pumpChart(
        tester,
        FocusTrendChart(
          research: data.research,
          learning: data.learning,
          period: GrowthPeriod.sevenDays,
        ),
      );
      expect(
        find.byKey(const ValueKey('growthFocusLineChart')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<LineChart>(find.byType(LineChart))
            .data
            .lineBarsData[0]
            .spots[0]
            .y,
        0,
      );

      await _pumpChart(
        tester,
        SleepTrendChart(sleep: data.sleep, period: GrowthPeriod.sevenDays),
      );
      expect(
        find.byKey(const ValueKey('growthSleepLineChart')),
        findsOneWidget,
      );

      await _pumpChart(
        tester,
        ExerciseTrendChart(
          exercise: data.exercise,
          period: GrowthPeriod.sevenDays,
        ),
      );
      final bar = tester.widget<BarChart>(find.byType(BarChart));
      expect(bar.data.barGroups.first.barRods.single.toY, 0);
    },
  );

  testWidgets('chart exposes an objective semantic summary and text legend', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final data = const GrowthPresentationMapper().map(
      growthTestSnapshot(
        dataForDay: (index, date) => index == 0
            ? const GrowthDayTestData(moodScore: 3, energyScore: 4)
            : const GrowthDayTestData(),
      ),
    );
    await _pumpChart(
      tester,
      MoodEnergyChart(
        mood: data.mood,
        energy: data.energy,
        period: GrowthPeriod.sevenDays,
      ),
    );

    expect(find.text('Mood'), findsOneWidget);
    expect(find.text('Energy'), findsOneWidget);
    expect(find.bySemanticsLabel('Mood 记录 1 天，Energy 记录 1 天'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('charts build without overflow on a 360px surface', (
    tester,
  ) async {
    final data = const GrowthPresentationMapper().map(
      growthTestSnapshot(
        dataForDay: (index, date) => GrowthDayTestData(
          researchMinutes: index * 15,
          learningMinutes: index * 10,
        ),
      ),
    );
    await _pumpChart(
      tester,
      FocusTrendChart(
        research: data.research,
        learning: data.learning,
        period: GrowthPeriod.sevenDays,
      ),
      size: const Size(360, 520),
    );

    expect(find.byKey(const ValueKey('growthFocusLineChart')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all-zero series render as recorded baseline data', (
    tester,
  ) async {
    final data = const GrowthPresentationMapper().map(
      growthTestSnapshot(
        dataForDay: (index, date) =>
            const GrowthDayTestData(researchMinutes: 0, learningMinutes: 0),
      ),
    );
    await _pumpChart(
      tester,
      FocusTrendChart(
        research: data.research,
        learning: data.learning,
        period: GrowthPeriod.sevenDays,
      ),
    );

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData, hasLength(2));
    expect(
      chart.data.lineBarsData.expand((series) => series.spots),
      everyElement(predicate<FlSpot>((spot) => spot.y == 0)),
    );
    expect(chart.data.maxY, greaterThan(0));
  });

  testWidgets('one valid point remains visible in thirty-day mode', (
    tester,
  ) async {
    final data = const GrowthPresentationMapper().map(
      growthTestSnapshot(
        period: GrowthPeriod.thirtyDays,
        dataForDay: (index, date) => index == 14
            ? const GrowthDayTestData(researchMinutes: 25)
            : const GrowthDayTestData(),
      ),
    );
    await _pumpChart(
      tester,
      FocusTrendChart(
        research: data.research,
        learning: data.learning,
        period: GrowthPeriod.thirtyDays,
      ),
    );

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(
      chart.data.lineBarsData.first.spots.where((spot) => !spot.isNull()),
      hasLength(1),
    );
    expect(chart.data.lineBarsData.first.dotData.show, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first, last, alternating, and disjoint values preserve gaps', (
    tester,
  ) async {
    final data = const GrowthPresentationMapper().map(
      growthTestSnapshot(
        dataForDay: (index, date) => GrowthDayTestData(
          researchMinutes: index == 0 || index == 6 || index.isEven
              ? index * 10
              : null,
          learningMinutes: index.isOdd ? index * 10 : null,
        ),
      ),
    );
    await _pumpChart(
      tester,
      FocusTrendChart(
        research: data.research,
        learning: data.learning,
        period: GrowthPeriod.sevenDays,
      ),
    );

    final bars = tester
        .widget<LineChart>(find.byType(LineChart))
        .data
        .lineBarsData;
    expect(bars[0].spots.first.y, 0);
    expect(bars[0].spots.last.y, 60);
    expect(bars[0].spots[1], FlSpot.nullSpot);
    expect(bars[1].spots[0], FlSpot.nullSpot);
    expect(bars[1].spots[1].y, 10);
    expect(tester.takeException(), isNull);
  });

  testWidgets('extreme minute values keep a finite upper axis boundary', (
    tester,
  ) async {
    final data = const GrowthPresentationMapper().map(
      growthTestSnapshot(
        dataForDay: (index, date) => index == 3
            ? const GrowthDayTestData(
                researchMinutes: 1000000,
                learningMinutes: 999999,
                exerciseMinutes: 1000000,
              )
            : const GrowthDayTestData(),
      ),
    );
    await _pumpChart(
      tester,
      FocusTrendChart(
        research: data.research,
        learning: data.learning,
        period: GrowthPeriod.sevenDays,
      ),
      size: const Size(320, 520),
      textScale: 2,
    );

    final line = tester.widget<LineChart>(find.byType(LineChart));
    expect(line.data.maxY, greaterThan(1000000));
    expect(line.data.maxY.isFinite, isTrue);
    expect(tester.takeException(), isNull);

    await _pumpChart(
      tester,
      ExerciseTrendChart(
        exercise: data.exercise,
        period: GrowthPeriod.sevenDays,
      ),
      size: const Size(320, 520),
      textScale: 2,
    );
    final bars = tester.widget<BarChart>(find.byType(BarChart));
    expect(bars.data.maxY, greaterThan(1000000));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mood and Energy values at 1 and 5 keep the fixed scale', (
    tester,
  ) async {
    final data = const GrowthPresentationMapper().map(
      growthTestSnapshot(
        dataForDay: (index, date) => index.isEven
            ? const GrowthDayTestData(moodScore: 1)
            : const GrowthDayTestData(energyScore: 5),
      ),
    );
    await _pumpChart(
      tester,
      MoodEnergyChart(
        mood: data.mood,
        energy: data.energy,
        period: GrowthPeriod.sevenDays,
      ),
    );

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.minY, 1);
    expect(chart.data.maxY, 5);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpChart(
  WidgetTester tester,
  Widget chart, {
  Size size = const Size(700, 520),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: chart,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
