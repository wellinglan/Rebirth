import 'package:rebirth/features/sync/domain/sync_models.dart';

import 'journal_entry.dart';

final class JournalSyncPayload implements SyncEntityPayload {
  const JournalSyncPayload({
    required this.entryDate,
    required this.timezoneOffsetMinutes,
    required this.mostImportantAccomplishment,
    required this.mostDrainingEvent,
    required this.emotionSource,
    required this.learning,
    required this.tomorrowAdjustment,
    required this.status,
    required this.createdAt,
  });

  final String entryDate;
  final int timezoneOffsetMinutes;
  final String? mostImportantAccomplishment;
  final String? mostDrainingEvent;
  final String? emotionSource;
  final String? learning;
  final String? tomorrowAdjustment;
  final JournalEntryStatus status;
  final int createdAt;

  bool get hasContent =>
      mostImportantAccomplishment != null ||
      mostDrainingEvent != null ||
      emotionSource != null ||
      learning != null ||
      tomorrowAdjustment != null;
}
