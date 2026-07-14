import 'package:rebirth/core/utils/date_time_service.dart';

import 'plan_goal.dart';

final class EmptyPlanGoalTitleException implements Exception {
  const EmptyPlanGoalTitleException();

  @override
  String toString() => 'A plan goal title must not be empty.';
}

final class InvalidPlanGoalDateException implements Exception {
  const InvalidPlanGoalDateException(this.fieldName, this.value);

  final String fieldName;
  final String value;

  @override
  String toString() => '$fieldName must be a valid YYYY-MM-DD date: $value.';
}

final class InvalidPlanGoalDateRangeException implements Exception {
  const InvalidPlanGoalDateRangeException();

  @override
  String toString() => 'A goal target date must not be before its start date.';
}

final class PlanGoalSaveData {
  factory PlanGoalSaveData({
    String? parentGoalId,
    required String title,
    String? description,
    required PlanGoalLevel goalLevel,
    PlanGoalStatus status = PlanGoalStatus.notStarted,
    String? startDate,
    String? targetDate,
    int sortOrder = 0,
  }) {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const EmptyPlanGoalTitleException();
    }

    final normalizedDescription = _trimToNull(description);
    _validateDate(startDate, 'startDate');
    _validateDate(targetDate, 'targetDate');
    if (startDate != null &&
        targetDate != null &&
        targetDate.compareTo(startDate) < 0) {
      throw const InvalidPlanGoalDateRangeException();
    }
    if (sortOrder < 0) {
      throw ArgumentError.value(
        sortOrder,
        'sortOrder',
        'Sort order must be non-negative.',
      );
    }

    return PlanGoalSaveData._(
      parentGoalId: _trimToNull(parentGoalId),
      title: normalizedTitle,
      description: normalizedDescription,
      goalLevel: goalLevel,
      status: status,
      startDate: startDate,
      targetDate: targetDate,
      sortOrder: sortOrder,
    );
  }

  const PlanGoalSaveData._({
    required this.parentGoalId,
    required this.title,
    required this.description,
    required this.goalLevel,
    required this.status,
    required this.startDate,
    required this.targetDate,
    required this.sortOrder,
  });

  static const DateTimeService _dateTimeService = DateTimeService();

  final String? parentGoalId;
  final String title;
  final String? description;
  final PlanGoalLevel goalLevel;
  final PlanGoalStatus status;
  final String? startDate;
  final String? targetDate;
  final int sortOrder;

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static void _validateDate(String? value, String fieldName) {
    if (value != null && !_dateTimeService.isValidLocalDateString(value)) {
      throw InvalidPlanGoalDateException(fieldName, value);
    }
  }
}
