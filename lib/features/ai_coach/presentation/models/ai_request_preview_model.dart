import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';

final class AiRequestPreviewModel {
  AiRequestPreviewModel({
    required this.reportTypeLabel,
    required this.periodStartDate,
    required this.periodEndDate,
    required this.promptVersion,
    required this.shortInputHash,
    required this.sourceCount,
    required List<AiDataScope> scopes,
    required this.growth,
    required List<AiTodayDayPreviewModel> todayDays,
    required List<AiHealthDayPreviewModel> healthDays,
    required List<AiJournalDayPreviewModel> journalDays,
  }) : scopes = List<AiDataScope>.unmodifiable(scopes),
       todayDays = List<AiTodayDayPreviewModel>.unmodifiable(todayDays),
       healthDays = List<AiHealthDayPreviewModel>.unmodifiable(healthDays),
       journalDays = List<AiJournalDayPreviewModel>.unmodifiable(journalDays);

  final String reportTypeLabel;
  final String periodStartDate;
  final String periodEndDate;
  final String promptVersion;
  final String shortInputHash;
  final int sourceCount;
  final List<AiDataScope> scopes;
  final AiGrowthPreviewModel? growth;
  final List<AiTodayDayPreviewModel> todayDays;
  final List<AiHealthDayPreviewModel> healthDays;
  final List<AiJournalDayPreviewModel> journalDays;
}

final class AiGrowthPreviewModel {
  const AiGrowthPreviewModel({
    required this.researchTotalMinutes,
    required this.learningTotalMinutes,
    required this.exerciseTotalMinutes,
    required this.averageSleepMinutes,
    required this.averageMood,
    required this.averageEnergy,
    required this.journalRecordedDays,
    required this.journalCompletedDays,
    required this.periodDays,
  });

  final int? researchTotalMinutes;
  final int? learningTotalMinutes;
  final int? exerciseTotalMinutes;
  final double? averageSleepMinutes;
  final double? averageMood;
  final double? averageEnergy;
  final int journalRecordedDays;
  final int journalCompletedDays;
  final int periodDays;
}

final class AiTodayDayPreviewModel {
  const AiTodayDayPreviewModel({
    required this.date,
    required this.researchMinutes,
    required this.learningMinutes,
    required this.moodScore,
    required this.energyScore,
    required this.populatedPriorityCount,
    required this.completedPriorityCount,
    required this.statusLabel,
  });

  final String date;
  final int? researchMinutes;
  final int? learningMinutes;
  final int? moodScore;
  final int? energyScore;
  final int populatedPriorityCount;
  final int completedPriorityCount;
  final String statusLabel;
}

final class AiHealthDayPreviewModel {
  const AiHealthDayPreviewModel({
    required this.date,
    required this.sleepDurationMinutes,
    required this.exerciseDurationMinutes,
    required this.physicalStateScore,
    required this.waterIntakeMl,
    required this.weightKg,
  });

  final String date;
  final int? sleepDurationMinutes;
  final int? exerciseDurationMinutes;
  final int? physicalStateScore;
  final int? waterIntakeMl;
  final double? weightKg;
}

final class AiJournalDayPreviewModel {
  const AiJournalDayPreviewModel({
    required this.date,
    required this.statusLabel,
    required this.mostImportantAccomplishment,
    required this.mostDrainingEvent,
    required this.emotionSource,
    required this.learning,
    required this.tomorrowAdjustment,
  });

  final String date;
  final String statusLabel;
  final String? mostImportantAccomplishment;
  final String? mostDrainingEvent;
  final String? emotionSource;
  final String? learning;
  final String? tomorrowAdjustment;
}
