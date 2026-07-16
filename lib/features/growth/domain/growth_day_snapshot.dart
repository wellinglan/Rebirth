import 'package:rebirth/core/utils/date_time_service.dart';

import 'growth_data_integrity_exception.dart';

final class GrowthDaySnapshot {
  GrowthDaySnapshot({
    required this.date,
    required this.researchMinutes,
    required this.learningMinutes,
    required this.exerciseMinutes,
    required this.sleepMinutes,
    required this.moodScore,
    required this.energyScore,
    required this.journalRecorded,
    required this.journalCompleted,
  }) {
    if (!const DateTimeService().isValidLocalDateString(date)) {
      throw GrowthDataIntegrityException(
        'Invalid Growth date "$date"; expected YYYY-MM-DD.',
      );
    }
    _validateMinutes(researchMinutes, 'researchMinutes');
    _validateMinutes(learningMinutes, 'learningMinutes');
    _validateMinutes(exerciseMinutes, 'exerciseMinutes');
    _validateMinutes(sleepMinutes, 'sleepMinutes');
    _validateScore(moodScore, 'moodScore');
    _validateScore(energyScore, 'energyScore');
    if (journalCompleted && !journalRecorded) {
      throw GrowthDataIntegrityException(
        'journalCompleted requires journalRecorded for $date.',
      );
    }
  }

  final String date;
  final int? researchMinutes;
  final int? learningMinutes;
  final int? exerciseMinutes;
  final int? sleepMinutes;
  final int? moodScore;
  final int? energyScore;
  final bool journalRecorded;
  final bool journalCompleted;

  void _validateMinutes(int? value, String field) {
    if (value != null && value < 0) {
      throw GrowthDataIntegrityException(
        '$field for $date must not be negative.',
      );
    }
  }

  void _validateScore(int? value, String field) {
    if (value != null && (value < 1 || value > 5)) {
      throw GrowthDataIntegrityException(
        '$field for $date must be between 1 and 5.',
      );
    }
  }
}
