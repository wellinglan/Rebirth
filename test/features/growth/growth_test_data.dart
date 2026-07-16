import 'package:rebirth/features/growth/domain/growth_day_snapshot.dart';
import 'package:rebirth/features/growth/domain/growth_metric_summary.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';
import 'package:rebirth/features/growth/domain/growth_snapshot.dart';

final class GrowthDayTestData {
  const GrowthDayTestData({
    this.researchMinutes,
    this.learningMinutes,
    this.exerciseMinutes,
    this.sleepMinutes,
    this.moodScore,
    this.energyScore,
    this.journalRecorded = false,
    this.journalCompleted = false,
  });

  final int? researchMinutes;
  final int? learningMinutes;
  final int? exerciseMinutes;
  final int? sleepMinutes;
  final int? moodScore;
  final int? energyScore;
  final bool journalRecorded;
  final bool journalCompleted;
}

GrowthSnapshot growthTestSnapshot({
  GrowthPeriod period = GrowthPeriod.sevenDays,
  DateTime? endDate,
  GrowthDayTestData Function(int index, String date)? dataForDay,
}) {
  final end = endDate ?? DateTime(2026, 7, 16);
  final start = DateTime(end.year, end.month, end.day - period.days + 1);
  final days = List<GrowthDaySnapshot>.generate(period.days, (index) {
    final date = DateTime(start.year, start.month, start.day + index);
    final dateString = _dateString(date);
    final data =
        dataForDay?.call(index, dateString) ?? const GrowthDayTestData();
    return GrowthDaySnapshot(
      date: dateString,
      researchMinutes: data.researchMinutes,
      learningMinutes: data.learningMinutes,
      exerciseMinutes: data.exerciseMinutes,
      sleepMinutes: data.sleepMinutes,
      moodScore: data.moodScore,
      energyScore: data.energyScore,
      journalRecorded: data.journalRecorded,
      journalCompleted: data.journalCompleted,
    );
  }, growable: false);

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
  );
}

String _dateString(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
