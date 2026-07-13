import 'journal_entry.dart';

final class JournalSaveData {
  const JournalSaveData({
    this.mostImportantAccomplishment,
    this.mostDrainingEvent,
    this.emotionSource,
    this.learning,
    this.tomorrowAdjustment,
    this.status = JournalEntryStatus.draft,
  });

  final String? mostImportantAccomplishment;
  final String? mostDrainingEvent;
  final String? emotionSource;
  final String? learning;
  final String? tomorrowAdjustment;
  final JournalEntryStatus status;
}
