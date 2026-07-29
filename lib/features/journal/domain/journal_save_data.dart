import 'journal_entry.dart';
import 'journal_entry_prompt_item.dart';

final class JournalSaveData {
  const JournalSaveData({
    this.mostImportantAccomplishment,
    this.mostDrainingEvent,
    this.emotionSource,
    this.learning,
    this.tomorrowAdjustment,
    this.promptItems,
    this.status = JournalEntryStatus.draft,
  });

  final String? mostImportantAccomplishment;
  final String? mostDrainingEvent;
  final String? emotionSource;
  final String? learning;
  final String? tomorrowAdjustment;
  final List<JournalEntryPromptItem>? promptItems;
  final JournalEntryStatus status;

  JournalSaveData withStatus(JournalEntryStatus status) {
    return JournalSaveData(
      mostImportantAccomplishment: mostImportantAccomplishment,
      mostDrainingEvent: mostDrainingEvent,
      emotionSource: emotionSource,
      learning: learning,
      tomorrowAdjustment: tomorrowAdjustment,
      promptItems: promptItems,
      status: status,
    );
  }
}
