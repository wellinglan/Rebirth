import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';

void main() {
  test('previewText prefers the accomplishment', () {
    final entry = _entry(
      mostImportantAccomplishment: '最重要完成',
      mostDrainingEvent: '消耗事件',
    );

    expect(entry.previewText, '最重要完成');
    expect(entry.hasContent, isTrue);
  });

  test('previewText uses the next non-empty reflection field', () {
    final entry = _entry(
      mostImportantAccomplishment: '  ',
      emotionSource: '情绪来源',
      learning: '今日学习',
    );

    expect(entry.previewText, '情绪来源');
    expect(entry.hasContent, isTrue);
  });

  test('previewText falls back when every field is empty', () {
    final entry = _entry(learning: '\n');

    expect(entry.previewText, '无内容');
    expect(entry.hasContent, isFalse);
  });
}

JournalEntry _entry({
  String? mostImportantAccomplishment,
  String? mostDrainingEvent,
  String? emotionSource,
  String? learning,
  String? tomorrowAdjustment,
}) {
  return JournalEntry(
    id: 'journal-id',
    userId: 'user-id',
    todayRecordId: null,
    entryDate: '2026-07-13',
    timezoneOffsetMinutes: 480,
    mostImportantAccomplishment: mostImportantAccomplishment,
    mostDrainingEvent: mostDrainingEvent,
    emotionSource: emotionSource,
    learning: learning,
    tomorrowAdjustment: tomorrowAdjustment,
    status: JournalEntryStatus.draft,
    createdAt: 1,
    updatedAt: 1,
  );
}
