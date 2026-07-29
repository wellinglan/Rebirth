import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/presentation/widgets/journal_history_formatters.dart';

void main() {
  test('history status includes date context and explicit lifecycle', () {
    expect(
      journalHistoryStatusLabel(
        entry: _entry(date: '2026-07-13', learning: '有内容'),
        today: '2026-07-14',
      ),
      '历史复盘 · 草稿',
    );
    expect(
      journalHistoryStatusLabel(
        entry: _entry(
          date: '2026-07-14',
          learning: '有内容',
          status: JournalEntryStatus.completed,
        ),
        today: '2026-07-14',
      ),
      '今日复盘 · 已完成',
    );
    expect(
      journalHistoryStatusLabel(
        entry: _entry(date: '2026-07-13'),
        today: '2026-07-14',
      ),
      '空复盘',
    );
  });
}

JournalEntry _entry({
  required String date,
  String? learning,
  JournalEntryStatus status = JournalEntryStatus.draft,
}) => JournalEntry(
  id: date,
  userId: 'user',
  todayRecordId: null,
  entryDate: date,
  timezoneOffsetMinutes: 480,
  mostImportantAccomplishment: null,
  mostDrainingEvent: null,
  emotionSource: null,
  learning: learning,
  tomorrowAdjustment: null,
  status: status,
  createdAt: 1,
  updatedAt: 1,
);
