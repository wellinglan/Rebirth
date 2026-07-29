// ignore_for_file: prefer_initializing_formals

import 'package:rebirth/core/journal/journal_prompt_catalog.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

import 'journal_entry.dart';
import 'journal_entry_prompt_item.dart';

final class JournalSyncPayload implements SyncEntityPayload {
  const JournalSyncPayload({
    required this.entryDate,
    required this.timezoneOffsetMinutes,
    required this.status,
    required this.createdAt,
    this.promptItems = const [],
    String? mostImportantAccomplishment,
    String? mostDrainingEvent,
    String? emotionSource,
    String? learning,
    String? tomorrowAdjustment,
  }) : _mostImportantAccomplishment = mostImportantAccomplishment,
       _mostDrainingEvent = mostDrainingEvent,
       _emotionSource = emotionSource,
       _learning = learning,
       _tomorrowAdjustment = tomorrowAdjustment;

  final String entryDate;
  final int timezoneOffsetMinutes;
  final JournalEntryStatus status;
  final int createdAt;
  final List<JournalEntryPromptItem> promptItems;

  // v1 compatibility fields. New writes use promptItems as the source of truth.
  final String? _mostImportantAccomplishment;
  final String? _mostDrainingEvent;
  final String? _emotionSource;
  final String? _learning;
  final String? _tomorrowAdjustment;

  String? get mostImportantAccomplishment =>
      _answerFor(JournalPromptCatalog.accomplishmentKey);
  String? get mostDrainingEvent =>
      _answerFor(JournalPromptCatalog.drainingEventKey);
  String? get emotionSource =>
      _answerFor(JournalPromptCatalog.emotionSourceKey);
  String? get learning => _answerFor(JournalPromptCatalog.learningKey);
  String? get tomorrowAdjustment =>
      _answerFor(JournalPromptCatalog.tomorrowAdjustmentKey);

  int get schemaVersion => promptItems.isEmpty ? 1 : 2;

  bool get hasContent => promptItems.isNotEmpty
      ? promptItems.any((item) => item.hasAnswer)
      : mostImportantAccomplishment != null ||
            mostDrainingEvent != null ||
            emotionSource != null ||
            learning != null ||
            tomorrowAdjustment != null;

  String? legacyAnswerFor(String stableKey) {
    return _answerFor(stableKey);
  }

  String? _answerFor(String stableKey) {
    for (final item in promptItems) {
      if (item.sourcePromptStableKey == stableKey) return item.answerText;
    }
    return switch (stableKey) {
      JournalPromptCatalog.accomplishmentKey => _mostImportantAccomplishment,
      JournalPromptCatalog.drainingEventKey => _mostDrainingEvent,
      JournalPromptCatalog.emotionSourceKey => _emotionSource,
      JournalPromptCatalog.learningKey => _learning,
      JournalPromptCatalog.tomorrowAdjustmentKey => _tomorrowAdjustment,
      _ => null,
    };
  }
}
