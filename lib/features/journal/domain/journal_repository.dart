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

final class JournalConflictPendingException implements Exception {
  const JournalConflictPendingException(this.id);

  final String id;

  @override
  String toString() =>
      'Journal entry $id has an unresolved synchronization conflict.';
}

abstract interface class JournalRepository {
  Future<JournalEntry> createEntry(JournalSaveData data);

  Future<JournalEntry?> getTodayEntry();

  Future<JournalEntry> saveTodayEntry(JournalSaveData data);

  Future<JournalEntry> saveDraft(JournalSaveData data);

  Future<JournalEntry> complete(JournalSaveData data);

  Future<JournalEntry> reopen(String id);

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
