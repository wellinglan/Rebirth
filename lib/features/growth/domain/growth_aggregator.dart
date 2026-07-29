import 'package:rebirth/features/personal_data/domain/personal_data_value.dart';

import 'growth_builtin_ids.dart';
import 'growth_data_integrity_exception.dart';
import 'growth_day_snapshot.dart';
import 'growth_metric_projection.dart';
import 'growth_metric_summary.dart';
import 'growth_period.dart';
import 'growth_projection.dart';
import 'growth_snapshot.dart';

/// Compatibility mapper that keeps the established chart model while Growth
/// now derives all values from the generic projection framework.
final class GrowthAggregator {
  const GrowthAggregator();

  GrowthSnapshot aggregate({
    required GrowthPeriod period,
    required List<String> dateRange,
    required GrowthProjection projection,
  }) {
    if (dateRange.length != period.days) {
      throw GrowthDataIntegrityException(
        '${period.name} requires ${period.days} dates, received '
        '${dateRange.length}.',
      );
    }

    final research = _metric(projection, GrowthMetrics.researchDuration);
    final learning = _metric(projection, GrowthMetrics.learningDuration);
    final exercise = _metric(projection, GrowthMetrics.exerciseDuration);
    final sleep = _metric(projection, GrowthMetrics.sleepDuration);
    final mood = _metric(projection, GrowthMetrics.moodScore);
    final energy = _metric(projection, GrowthMetrics.energyScore);
    final reflection = _metric(projection, GrowthMetrics.reflectionStatus);

    final days = [
      for (final date in dateRange)
        GrowthDaySnapshot(
          date: date,
          researchMinutes: _minutes(research, date),
          learningMinutes: _minutes(learning, date),
          exerciseMinutes: _minutes(exercise, date),
          sleepMinutes: _minutes(sleep, date),
          moodScore: _score(mood, date),
          energyScore: _score(energy, date),
          journalRecorded: _journalStatus(reflection, date) != 'missing',
          journalCompleted: _journalStatus(reflection, date) == 'completed',
        ),
    ];

    return GrowthSnapshot(
      period: period,
      startDate: days.first.date,
      endDate: days.last.date,
      days: days,
      researchSummary: GrowthMetricSummary.fromValues(
        days.map((day) => day.researchMinutes),
      ),
      learningSummary: GrowthMetricSummary.fromValues(
        days.map((day) => day.learningMinutes),
      ),
      exerciseSummary: GrowthMetricSummary.fromValues(
        days.map((day) => day.exerciseMinutes),
      ),
      sleepSummary: GrowthMetricSummary.fromValues(
        days.map((day) => day.sleepMinutes),
      ),
      moodSummary: GrowthMetricSummary.fromValues(
        days.map((day) => day.moodScore),
      ),
      energySummary: GrowthMetricSummary.fromValues(
        days.map((day) => day.energyScore),
      ),
      journalRecordedDays: days.where((day) => day.journalRecorded).length,
      journalCompletedDays: days.where((day) => day.journalCompleted).length,
      projection: projection,
    );
  }

  GrowthMetricProjection? _metric(
    GrowthProjection projection,
    Object metricId,
  ) {
    for (final dimension in projection.dimensions) {
      for (final metric in dimension.metrics) {
        if (metric.metricId == metricId) return metric;
      }
    }
    return null;
  }

  int? _minutes(GrowthMetricProjection? metric, String date) {
    final value = _valueFor(metric, date);
    return value is PersonalDataDurationValue ? value.minutes : null;
  }

  int? _score(GrowthMetricProjection? metric, String date) {
    final value = _valueFor(metric, date);
    return value is PersonalDataScoreValue ? value.value.round() : null;
  }

  String _journalStatus(GrowthMetricProjection? metric, String date) {
    final value = _valueFor(metric, date);
    return value is PersonalDataCategoricalValue ? value.value : 'missing';
  }

  PersonalDataValue? _valueFor(GrowthMetricProjection? metric, String date) {
    if (metric == null) return null;
    for (final point in metric.series) {
      if (point.localDate == date) return point.value;
    }
    return null;
  }
}
