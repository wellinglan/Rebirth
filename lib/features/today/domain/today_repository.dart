import 'today_entry.dart';
import 'today_save_data.dart';

abstract interface class TodayRepository {
  Future<TodayEntry> getToday();

  Future<TodayEntry?> getByDate(String recordDate);

  Future<TodayEntry> saveToday(TodaySaveData data);

  Future<TodayEntry> updatePriorities({
    required String recordDate,
    required List<TodayPriority> priorities,
  });

  Future<TodayEntry> updateMoodEnergy({
    required String recordDate,
    required int? moodScore,
    required int? energyScore,
  });

  Future<TodayEntry> updateResearchLearningMinutes({
    required String recordDate,
    required int? researchMinutes,
    required int? learningMinutes,
  });

  Future<TodayEntry> updateDailyNote({
    required String recordDate,
    required String? dailyNote,
  });

  Future<TodayEntry> markCompleted({
    required String recordDate,
    required bool completed,
  });
}
