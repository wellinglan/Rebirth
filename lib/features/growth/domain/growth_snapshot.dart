import 'growth_day_snapshot.dart';
import 'growth_metric_summary.dart';
import 'growth_period.dart';

final class GrowthSnapshot {
  GrowthSnapshot({
    required this.period,
    required this.startDate,
    required this.endDate,
    required List<GrowthDaySnapshot> days,
    required this.researchSummary,
    required this.learningSummary,
    required this.exerciseSummary,
    required this.sleepSummary,
    required this.moodSummary,
    required this.energySummary,
    required this.journalRecordedDays,
    required this.journalCompletedDays,
  }) : days = List<GrowthDaySnapshot>.unmodifiable(days) {
    if (days.length != period.days) {
      throw ArgumentError.value(
        days.length,
        'days',
        'GrowthSnapshot must contain exactly ${period.days} days.',
      );
    }
    if (startDate != days.first.date || endDate != days.last.date) {
      throw ArgumentError(
        'startDate and endDate must match the first and last day.',
      );
    }
    for (var index = 1; index < days.length; index += 1) {
      if (days[index - 1].date.compareTo(days[index].date) >= 0) {
        throw ArgumentError('GrowthSnapshot days must be strictly ascending.');
      }
    }
  }

  final GrowthPeriod period;
  final String startDate;
  final String endDate;
  final List<GrowthDaySnapshot> days;
  final GrowthMetricSummary researchSummary;
  final GrowthMetricSummary learningSummary;
  final GrowthMetricSummary exerciseSummary;
  final GrowthMetricSummary sleepSummary;
  final GrowthMetricSummary moodSummary;
  final GrowthMetricSummary energySummary;
  final int journalRecordedDays;
  final int journalCompletedDays;
}
