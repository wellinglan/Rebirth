import 'package:rebirth/features/journal/domain/journal_entry.dart';

String journalHistoryStatusLabel({
  required JournalEntry entry,
  required String today,
}) {
  if (!entry.hasContent) return '空复盘';
  final dateLabel = entry.entryDate == today ? '今日复盘' : '历史复盘';
  return '$dateLabel · ${entry.status.displayLabel}';
}
