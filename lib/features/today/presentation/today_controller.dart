import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/today/data/today_repository_provider.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_repository.dart';
import 'package:rebirth/features/today/domain/today_save_data.dart';

final todayControllerProvider =
    AsyncNotifierProvider<TodayController, TodayEntry>(TodayController.new);

class TodayController extends AsyncNotifier<TodayEntry> {
  @override
  Future<TodayEntry> build() {
    return ref.watch(todayRepositoryProvider).getToday();
  }

  Future<void> reload() {
    return _reload(() => ref.read(todayRepositoryProvider).getToday());
  }

  Future<void> saveToday(TodaySaveData data) {
    return _mutate(() => ref.read(todayRepositoryProvider).saveToday(data));
  }

  Future<void> updatePriorities(List<TodayPriority> priorities) {
    return _runWithCurrent((repository, current) {
      return repository.updatePriorities(
        recordDate: current.recordDate,
        priorities: priorities,
      );
    });
  }

  Future<void> updateMoodEnergy({int? moodScore, int? energyScore}) {
    return _runWithCurrent((repository, current) {
      return repository.updateMoodEnergy(
        recordDate: current.recordDate,
        moodScore: moodScore,
        energyScore: energyScore,
      );
    });
  }

  Future<void> updateResearchLearningMinutes({
    int? researchMinutes,
    int? learningMinutes,
  }) {
    return _runWithCurrent((repository, current) {
      return repository.updateResearchLearningMinutes(
        recordDate: current.recordDate,
        researchMinutes: researchMinutes,
        learningMinutes: learningMinutes,
      );
    });
  }

  Future<void> updateDailyNote(String? dailyNote) {
    return _runWithCurrent((repository, current) {
      return repository.updateDailyNote(
        recordDate: current.recordDate,
        dailyNote: dailyNote,
      );
    });
  }

  Future<void> markCompleted(bool completed) {
    return _runWithCurrent((repository, current) {
      return repository.markCompleted(
        recordDate: current.recordDate,
        completed: completed,
      );
    });
  }

  Future<void> _runWithCurrent(
    Future<TodayEntry> Function(TodayRepository repository, TodayEntry current)
    operation,
  ) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    await _mutate(() => operation(ref.read(todayRepositoryProvider), current));
  }

  Future<void> _reload(Future<TodayEntry> Function() operation) async {
    state = const AsyncLoading<TodayEntry>();
    state = await AsyncValue.guard(operation);
  }

  Future<void> _mutate(Future<TodayEntry> Function() operation) async {
    final updated = await operation();
    state = AsyncData(updated);
  }
}
