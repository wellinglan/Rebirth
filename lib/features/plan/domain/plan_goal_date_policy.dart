import 'dart:math' as math;

import 'package:rebirth/core/utils/date_time_service.dart';

import 'plan_goal.dart';

final class PlanGoalDatePolicy {
  const PlanGoalDatePolicy();

  String defaultStartDate(DateTimeService dateTimeService) {
    return dateTimeService.currentLocalDateString();
  }

  String? targetDate({
    required PlanGoalLevel level,
    required String startDate,
    String? currentTargetDate,
  }) {
    final start = _parseDate(startDate);
    return switch (level) {
      PlanGoalLevel.day => _format(
        DateTime(start.year, start.month, start.day + 1),
      ),
      PlanGoalLevel.week => _format(
        DateTime(start.year, start.month, start.day + 7),
      ),
      PlanGoalLevel.month => _addMonths(start, 1),
      PlanGoalLevel.quarter => _addMonths(start, 3),
      PlanGoalLevel.year => _addMonths(start, 12),
      PlanGoalLevel.life => null,
      PlanGoalLevel.custom => currentTargetDate,
    };
  }

  String _addMonths(DateTime start, int months) {
    final targetMonthIndex = start.year * 12 + start.month - 1 + months;
    final targetYear = targetMonthIndex ~/ 12;
    final targetMonth = targetMonthIndex % 12 + 1;
    final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
    final targetDay = math.min(start.day, lastDay);
    return _format(DateTime(targetYear, targetMonth, targetDay));
  }

  DateTime _parseDate(String value) {
    const service = DateTimeService();
    if (!service.isValidLocalDateString(value)) {
      throw ArgumentError.value(
        value,
        'startDate',
        'Expected a valid YYYY-MM-DD date.',
      );
    }
    return DateTime(
      int.parse(value.substring(0, 4)),
      int.parse(value.substring(5, 7)),
      int.parse(value.substring(8, 10)),
    );
  }

  String _format(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
