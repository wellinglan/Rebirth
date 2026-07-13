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
}
