import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/health/domain/health_entry.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';

import 'growth_data_integrity_exception.dart';
import 'growth_day_snapshot.dart';
import 'growth_metric_summary.dart';
import 'growth_period.dart';
import 'growth_snapshot.dart';

final class GrowthAggregator {
  const GrowthAggregator();

  GrowthSnapshot aggregate({
    required GrowthPeriod period,
    required List<String> dateRange,
    required List<TodayEntry> todayEntries,
    required List<HealthEntry> healthEntries,
    required List<JournalEntry> journalEntries,
  }) {
    _validateDateRange(period, dateRange);
    final includedDates = dateRange.toSet();
    final todayByDate = _indexToday(todayEntries, includedDates);
    final healthByDate = _indexHealth(healthEntries, includedDates);
    final journalByDate = _indexJournals(journalEntries, includedDates);

    final days = dateRange
        .map((date) {
          final today = todayByDate[date];
          final health = healthByDate[date];
          final journal = journalByDate[date];

          return GrowthDaySnapshot(
            date: date,
            researchMinutes: today?.researchMinutes,
            learningMinutes: today?.learningMinutes,
            exerciseMinutes: health?.exerciseDurationMinutes,
            sleepMinutes: health?.sleepDurationMinutes,
            moodScore: today?.moodScore,
            energyScore: today?.energyScore,
            journalRecorded: journal != null,
            journalCompleted:
                journal != null &&
                journal.status == JournalEntryStatus.completed,
          );
        })
        .toList(growable: false);

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

  void _validateDateRange(GrowthPeriod period, List<String> dateRange) {
    if (dateRange.length != period.days) {
      throw GrowthDataIntegrityException(
        '${period.name} requires ${period.days} dates, received '
        '${dateRange.length}.',
      );
    }

    for (var index = 0; index < dateRange.length; index += 1) {
      _validateDate(dateRange[index], 'date range');
      if (index > 0 && dateRange[index - 1].compareTo(dateRange[index]) >= 0) {
        throw const GrowthDataIntegrityException(
          'Growth date range must be strictly ascending.',
        );
      }
    }
  }

  Map<String, TodayEntry> _indexToday(
    List<TodayEntry> entries,
    Set<String> includedDates,
  ) {
    final byDate = <String, TodayEntry>{};
    for (final entry in entries) {
      _validateDate(entry.recordDate, 'Today record');
      if (!includedDates.contains(entry.recordDate)) {
        continue;
      }
      if (byDate.containsKey(entry.recordDate)) {
        throw GrowthDataIntegrityException(
          'Duplicate Today records for ${entry.recordDate}.',
        );
      }
      byDate[entry.recordDate] = entry;
    }
    return byDate;
  }

  Map<String, HealthEntry> _indexHealth(
    List<HealthEntry> entries,
    Set<String> includedDates,
  ) {
    final byDate = <String, HealthEntry>{};
    for (final entry in entries) {
      _validateDate(entry.recordDate, 'Health record');
      if (!includedDates.contains(entry.recordDate)) {
        continue;
      }
      if (byDate.containsKey(entry.recordDate)) {
        throw GrowthDataIntegrityException(
          'Duplicate Health records for ${entry.recordDate}.',
        );
      }
      byDate[entry.recordDate] = entry;
    }
    return byDate;
  }

  Map<String, JournalEntry> _indexJournals(
    List<JournalEntry> entries,
    Set<String> includedDates,
  ) {
    final byDate = <String, JournalEntry>{};
    for (final entry in entries) {
      _validateDate(entry.entryDate, 'Journal entry');
      if (!includedDates.contains(entry.entryDate) || !entry.hasContent) {
        continue;
      }
      if (byDate.containsKey(entry.entryDate)) {
        throw GrowthDataIntegrityException(
          'Duplicate Journal entries with content for ${entry.entryDate}.',
        );
      }
      byDate[entry.entryDate] = entry;
    }
    return byDate;
  }

  void _validateDate(String date, String source) {
    if (!const DateTimeService().isValidLocalDateString(date)) {
      throw GrowthDataIntegrityException(
        '$source contains invalid date "$date".',
      );
    }
  }
}
