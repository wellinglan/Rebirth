import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/journal/data/journal_repository_provider.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_save_data.dart';

final journalControllerProvider =
    AsyncNotifierProvider<JournalController, List<JournalEntry>>(
      JournalController.new,
    );

class JournalController extends AsyncNotifier<List<JournalEntry>> {
  int _limit = 20;

  @override
  Future<List<JournalEntry>> build() {
    return ref.watch(journalRepositoryProvider).listRecent(limit: _limit);
  }

  Future<void> loadRecent({int limit = 20}) {
    _limit = limit;
    return _load(
      () => ref.read(journalRepositoryProvider).listRecent(limit: _limit),
    );
  }

  Future<void> reload() => loadRecent(limit: _limit);

  Future<void> createEntry(JournalSaveData data) {
    return _mutate(() async {
      final repository = ref.read(journalRepositoryProvider);
      await repository.createEntry(data);
      return repository.listRecent(limit: _limit);
    });
  }

  Future<void> updateEntry({
    required String id,
    required JournalSaveData data,
  }) {
    return _mutate(() async {
      final repository = ref.read(journalRepositoryProvider);
      await repository.updateEntry(id: id, data: data);
      return repository.listRecent(limit: _limit);
    });
  }

  Future<void> deleteEntry(String id) {
    return _mutate(() async {
      final repository = ref.read(journalRepositoryProvider);
      await repository.softDelete(id);
      return repository.listRecent(limit: _limit);
    });
  }

  Future<void> _load(Future<List<JournalEntry>> Function() operation) async {
    state = const AsyncLoading<List<JournalEntry>>();
    await _setFrom(operation);
  }

  Future<void> _mutate(Future<List<JournalEntry>> Function() operation) {
    return _setFrom(operation);
  }

  Future<void> _setFrom(Future<List<JournalEntry>> Function() operation) async {
    try {
      state = AsyncData(await operation());
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
