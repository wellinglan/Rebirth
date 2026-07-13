import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/journal/data/journal_repository_provider.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_save_data.dart';

final journalTodayControllerProvider =
    AsyncNotifierProvider<JournalTodayController, JournalEntry?>(
      JournalTodayController.new,
    );

class JournalTodayController extends AsyncNotifier<JournalEntry?> {
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
    final saved = await ref
        .read(journalRepositoryProvider)
        .saveTodayEntry(data);
    state = AsyncData(saved);
  }
}
