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
}

Future<void> _pumpChart(
  WidgetTester tester,
  Widget chart, {
  Size size = const Size(700, 520),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
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
