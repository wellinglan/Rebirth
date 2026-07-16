import 'package:rebirth/features/growth/domain/growth_day_snapshot.dart';
import 'package:rebirth/features/growth/domain/growth_snapshot.dart';

import 'models/growth_chart_models.dart';

final class GrowthPresentationMapper {
  const GrowthPresentationMapper();

  GrowthPresentationData map(GrowthSnapshot snapshot) {
    return GrowthPresentationData(
      research: _series(
        snapshot.days,
        metric: GrowthChartMetric.research,
        label: '科研',
        select: (day) => day.researchMinutes,
      ),
      learning: _series(
        snapshot.days,
        metric: GrowthChartMetric.learning,
        label: '学习',
        select: (day) => day.learningMinutes,
      ),
      sleep: _series(
        snapshot.days,
        metric: GrowthChartMetric.sleep,
        label: '睡眠',
        select: (day) => day.sleepMinutes,
      ),
      exercise: _series(
        snapshot.days,
        metric: GrowthChartMetric.exercise,
        label: '运动',
        select: (day) => day.exerciseMinutes,
      ),
      mood: _series(
        snapshot.days,
        metric: GrowthChartMetric.mood,
        label: 'Mood',
        select: (day) => day.moodScore,
      ),
      energy: _series(
        snapshot.days,
        metric: GrowthChartMetric.energy,
        label: 'Energy',
        select: (day) => day.energyScore,
      ),
      journalDays: snapshot.days
          .map((day) {
            final status = day.journalCompleted
                ? GrowthJournalDayStatus.completed
                : day.journalRecorded
                ? GrowthJournalDayStatus.recordedDraft
                : GrowthJournalDayStatus.missing;
            return GrowthJournalDay(date: day.date, status: status);
          })
          .toList(growable: false),
    );
  }

  GrowthChartSeries _series(
    List<GrowthDaySnapshot> days, {
    required GrowthChartMetric metric,
    required String label,
    required int? Function(GrowthDaySnapshot day) select,
  }) {
    return GrowthChartSeries(
      metric: metric,
      label: label,
      points: List<GrowthChartPoint>.generate(
        days.length,
        (index) => GrowthChartPoint(
          index: index,
          date: days[index].date,
          value: select(days[index]),
        ),
        growable: false,
      ),
    );
  }
}
