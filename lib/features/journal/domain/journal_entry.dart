enum JournalEntryStatus { draft, completed }

final class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.userId,
    required this.todayRecordId,
    required this.entryDate,
    required this.timezoneOffsetMinutes,
    required this.mostImportantAccomplishment,
    required this.mostDrainingEvent,
    required this.emotionSource,
    required this.learning,
    required this.tomorrowAdjustment,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String? todayRecordId;
  final String entryDate;
  final int timezoneOffsetMinutes;
  final String? mostImportantAccomplishment;
  final String? mostDrainingEvent;
  final String? emotionSource;
  final String? learning;
  final String? tomorrowAdjustment;
  final JournalEntryStatus status;
  final int createdAt;
  final int updatedAt;

  bool get hasContent =>
      _contentFields.any((value) => value != null && value.trim().isNotEmpty);

  String get previewText {
    for (final value in _contentFields) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return '无内容';
  }

  List<String?> get _contentFields => [
    mostImportantAccomplishment,
    mostDrainingEvent,
    emotionSource,
    learning,
    tomorrowAdjustment,
  ];
}
