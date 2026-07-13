import 'today_entry.dart';

final class TodayHealthInput {
  const TodayHealthInput({
    this.sleepDurationMinutes,
    this.weightKg,
    this.waterIntakeMl,
    this.exerciseType,
    this.exerciseDurationMinutes,
    this.physicalStateScore,
    this.note,
  });

  final int? sleepDurationMinutes;
  final double? weightKg;
  final int? waterIntakeMl;
  final String? exerciseType;
  final int? exerciseDurationMinutes;
  final int? physicalStateScore;
  final String? note;
}

final class TodaySaveData {
  TodaySaveData({
    List<TodayPriority> priorities = const <TodayPriority>[
      TodayPriority(),
      TodayPriority(),
      TodayPriority(),
    ],
    this.moodScore,
    this.energyScore,
    this.researchMinutes,
    this.learningMinutes,
    this.dailyNote,
    this.status = TodayRecordStatus.draft,
    this.health,
  }) : priorities = List<TodayPriority>.unmodifiable(priorities);

  final List<TodayPriority> priorities;
  final int? moodScore;
  final int? energyScore;
  final int? researchMinutes;
  final int? learningMinutes;
  final String? dailyNote;
  final TodayRecordStatus status;
  final TodayHealthInput? health;
}
