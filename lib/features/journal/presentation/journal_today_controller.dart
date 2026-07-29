import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/journal/data/journal_repository_provider.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_repository.dart';
import 'package:rebirth/features/journal/domain/journal_save_data.dart';
import 'package:rebirth/features/growth/presentation/growth_controller.dart';
import 'package:rebirth/features/personal_data/application/personal_data_aggregation_controller.dart';

final journalTodayControllerProvider =
    AsyncNotifierProvider<JournalTodayController, JournalEntry?>(
      JournalTodayController.new,
    );

class JournalTodayController extends AsyncNotifier<JournalEntry?> {
  bool _mutationInProgress = false;

  @override
  Future<JournalEntry?> build() {
    return ref.watch(journalRepositoryProvider).getTodayEntry();
  }

  Future<void> reload() async {
    state = const AsyncLoading<JournalEntry?>();
    state = await AsyncValue.guard(
      ref.read(journalRepositoryProvider).getTodayEntry,
    );
  }

  Future<void> saveTodayEntry(JournalSaveData data) async {
    await saveDraft(data);
  }

  Future<void> saveDraft(JournalSaveData data) {
    return _mutate(() => ref.read(journalRepositoryProvider).saveDraft(data));
  }

  Future<void> completeReflection(JournalSaveData data) {
    return _mutate(() => ref.read(journalRepositoryProvider).complete(data));
  }

  Future<void> reopen() {
    final entry = state.asData?.value;
    if (entry == null) {
      return Future.error(const JournalEntryNotFoundException('today'));
    }
    return _mutate(() => ref.read(journalRepositoryProvider).reopen(entry.id));
  }

  Future<void> _mutate(Future<JournalEntry> Function() operation) async {
    if (_mutationInProgress) return;
    _mutationInProgress = true;
    final previous = state;
    try {
      final saved = await operation();
      if (!ref.mounted) return;
      state = AsyncData(saved);
      ref
        ..invalidate(personalDataAggregationControllerProvider)
        ..invalidate(growthControllerProvider);
    } catch (_) {
      if (ref.mounted) state = previous;
      rethrow;
    } finally {
      _mutationInProgress = false;
    }
  }
}
