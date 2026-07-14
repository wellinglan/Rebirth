enum TodayRecordStatus { draft, completed }

final class TodayPriority {
  const TodayPriority({this.text, this.completed = false, this.goalId});

  final String? text;
  final bool completed;
  final String? goalId;

  bool get isPopulated => text != null && text!.trim().isNotEmpty;
}

final class TodayHealthSummary {
  const TodayHealthSummary({
    required this.id,
    this.sleepDurationMinutes,
    this.weightKg,
    this.waterIntakeMl,
    this.exerciseType,
    this.exerciseDurationMinutes,
    this.physicalStateScore,
    this.note,
  });

  final String id;
  final int? sleepDurationMinutes;
  final double? weightKg;
  final int? waterIntakeMl;
  final String? exerciseType;
  final int? exerciseDurationMinutes;
  final int? physicalStateScore;
  final String? note;
}

final class TodayEntry {
  TodayEntry({
    required this.id,
    required this.userId,
    required this.recordDate,
    required this.timezoneOffsetMinutes,
    required List<TodayPriority> priorities,
    required this.moodScore,
    required this.energyScore,
    required this.researchMinutes,
    required this.learningMinutes,
    required this.dailyNote,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.health,
  }) : priorities = List<TodayPriority>.unmodifiable(priorities) {
    if (priorities.length != 3) {
      throw ArgumentError.value(
        priorities.length,
        'priorities',
        'Today entries must contain exactly three priority slots.',
      );
    }
  }

  final String id;
  final String userId;
  final String recordDate;
  final int timezoneOffsetMinutes;
  final List<TodayPriority> priorities;
  final int? moodScore;
  final int? energyScore;
  final int? researchMinutes;
  final int? learningMinutes;
  final String? dailyNote;
  final TodayRecordStatus status;
  final int createdAt;
  final int updatedAt;
  final TodayHealthSummary? health;

  int get populatedPriorityCount =>
      priorities.where((priority) => priority.isPopulated).length;

  int get completedPriorityCount => priorities
      .where((priority) => priority.isPopulated && priority.completed)
      .length;

  bool get hasContent =>
      priorities.any((priority) => priority.isPopulated) ||
      moodScore != null ||
      energyScore != null ||
      researchMinutes != null ||
      learningMinutes != null ||
      (dailyNote?.trim().isNotEmpty ?? false) ||
      _healthHasContent;

  bool get _healthHasContent {
    final summary = health;
    return summary != null &&
        (summary.sleepDurationMinutes != null ||
            summary.weightKg != null ||
            summary.waterIntakeMl != null ||
            (summary.exerciseType?.trim().isNotEmpty ?? false) ||
            summary.exerciseDurationMinutes != null ||
            summary.physicalStateScore != null ||
            (summary.note?.trim().isNotEmpty ?? false));
  }
}
