import 'journal_entry.dart';
import 'journal_save_data.dart';

final class EmptyJournalContentException implements Exception {
  const EmptyJournalContentException();

  @override
  String toString() =>
      'A journal entry must contain at least one reflection answer.';
}

final class JournalEntryNotFoundException implements Exception {
  const JournalEntryNotFoundException(this.id);

  final String id;

  @override
  String toString() => 'No active journal entry exists with ID $id.';
}

abstract interface class JournalRepository {
  Future<JournalEntry> createEntry(JournalSaveData data);

  Future<JournalEntry?> getById(String id);

  Future<List<JournalEntry>> listRecent({int limit = 20});

  Future<List<JournalEntry>> listByDate(String entryDate);

  Future<List<JournalEntry>> listByDateRange({
    required String startDate,
    required String endDate,
    int? limit,
  });

  Future<JournalEntry> updateEntry({
    required String id,
    required JournalSaveData data,
  });

  Future<void> softDelete(String id);
}
