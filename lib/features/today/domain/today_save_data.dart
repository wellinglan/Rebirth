import 'today_entry.dart';

final class TodayHealthInput {
  const TodayHealthInput({
    this.sleepDurationMinutes,
    this.sleepDescription,
    this.weightKg,
    this.weightDescription,
    this.waterIntakeMl,
    this.waterDescription,
    this.exerciseType,
    this.exerciseDurationMinutes,
    this.exerciseDescription,
    this.physicalStateScore,
    this.physicalStateDescription,
    this.note,
  });

  final int? sleepDurationMinutes;
  final String? sleepDescription;
  final double? weightKg;
  final String? weightDescription;
  final int? waterIntakeMl;
  final String? waterDescription;
  final String? exerciseType;
  final int? exerciseDurationMinutes;
  final String? exerciseDescription;
  final int? physicalStateScore;
  final String? physicalStateDescription;
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
    this.moodDescription,
    this.energyScore,
    this.energyDescription,
    this.researchMinutes,
    this.researchDescription,
    this.learningMinutes,
    this.learningDescription,
    this.dailyNote,
    this.status = TodayRecordStatus.draft,
    this.health,
  }) : priorities = List<TodayPriority>.unmodifiable(priorities);

  final List<TodayPriority> priorities;
  final int? moodScore;
  final String? moodDescription;
  final int? energyScore;
  final String? energyDescription;
  final int? researchMinutes;
  final String? researchDescription;
  final int? learningMinutes;
  final String? learningDescription;
  final String? dailyNote;
  final TodayRecordStatus status;
  final TodayHealthInput? health;
}
