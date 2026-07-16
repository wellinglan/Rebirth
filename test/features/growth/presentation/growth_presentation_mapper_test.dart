import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/growth/presentation/growth_presentation_mapper.dart';
import 'package:rebirth/features/growth/presentation/models/growth_chart_models.dart';

import '../growth_test_data.dart';

void main() {
  test(
    'maps every metric in ascending date order while preserving null and zero',
    () {
      final snapshot = growthTestSnapshot(
        dataForDay: (index, date) => switch (index) {
          0 => const GrowthDayTestData(
            researchMinutes: null,
            learningMinutes: 0,
            sleepMinutes: 420,
            exerciseMinutes: 30,
            moodScore: 3,
            energyScore: 4,
          ),
          1 => const GrowthDayTestData(
            researchMinutes: 0,
            learningMinutes: 60,
            sleepMinutes: null,
            exerciseMinutes: 0,
            moodScore: null,
            energyScore: 2,
          ),
          _ => const GrowthDayTestData(),
        },
      );

      final result = const GrowthPresentationMapper().map(snapshot);

      expect(result.research.points.map((point) => point.value), [
        null,
        0,
        null,
        null,
        null,
        null,
        null,
      ]);
      expect(result.learning.points.take(2).map((point) => point.value), [
        0,
        60,
      ]);
      expect(result.sleep.points.take(2).map((point) => point.value), [
        420,
        null,
      ]);
      expect(result.exercise.points.take(2).map((point) => point.value), [
        30,
        0,
      ]);
      expect(result.mood.points.take(2).map((point) => point.value), [3, null]);
      expect(result.energy.points.take(2).map((point) => point.value), [4, 2]);
      expect(result.research.points.first.index, 0);
      expect(result.research.points.last.index, 6);
      expect(
        result.research.points.map((point) => point.date),
        orderedEquals(snapshot.days.map((day) => day.date)),
      );
    },
  );

  test('maps Journal missing, draft, and completed states', () {
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

    final days = const GrowthPresentationMapper().map(snapshot).journalDays;

    expect(days[0].status, GrowthJournalDayStatus.missing);
    expect(days[1].status, GrowthJournalDayStatus.recordedDraft);
    expect(days[2].status, GrowthJournalDayStatus.completed);
    expect(
      days.map((day) => day.date),
      orderedEquals(snapshot.days.map((day) => day.date)),
    );
  });

  test('presentation collections are immutable', () {
    final result = const GrowthPresentationMapper().map(growthTestSnapshot());

    expect(
      () => result.research.points.add(result.research.points.first),
      throwsUnsupportedError,
    );
    expect(
      () => result.journalDays.add(result.journalDays.first),
      throwsUnsupportedError,
    );
  });
}
