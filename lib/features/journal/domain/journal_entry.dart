import 'package:rebirth/core/journal/journal_prompt_catalog.dart';
import 'package:rebirth/core/utils/deterministic_uuid.dart';

import 'journal_entry_prompt_item.dart';
import 'journal_prompt.dart';

enum JournalEntryStatus { draft, completed }

extension JournalEntryStatusPresentation on JournalEntryStatus {
  String get displayLabel => switch (this) {
    JournalEntryStatus.draft => '草稿',
    JournalEntryStatus.completed => '已完成',
  };
}

final class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.userId,
    required this.todayRecordId,
    required this.entryDate,
    required this.timezoneOffsetMinutes,
    List<JournalEntryPromptItem>? promptItems,
    String? mostImportantAccomplishment,
    String? mostDrainingEvent,
    String? emotionSource,
    String? learning,
    String? tomorrowAdjustment,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  }) : // Kept public for compatibility while the fixed-field API is retired.
       // ignore: prefer_initializing_formals
       _promptItems = promptItems,
       _legacyMostImportantAccomplishment = mostImportantAccomplishment,
       _legacyMostDrainingEvent = mostDrainingEvent,
       _legacyEmotionSource = emotionSource,
       _legacyLearning = learning,
       _legacyTomorrowAdjustment = tomorrowAdjustment;

  final String id;
  final String userId;
  final String? todayRecordId;
  final String entryDate;
  final int timezoneOffsetMinutes;
  final List<JournalEntryPromptItem>? _promptItems;
  final String? _legacyMostImportantAccomplishment;
  final String? _legacyMostDrainingEvent;
  final String? _legacyEmotionSource;
  final String? _legacyLearning;
  final String? _legacyTomorrowAdjustment;
  final JournalEntryStatus status;
  final int createdAt;
  final int updatedAt;

  List<JournalEntryPromptItem> get promptItems {
    final items =
        _promptItems ??
        _legacyItems(
          entryId: id,
          mostImportantAccomplishment: _legacyMostImportantAccomplishment,
          mostDrainingEvent: _legacyMostDrainingEvent,
          emotionSource: _legacyEmotionSource,
          learning: _legacyLearning,
          tomorrowAdjustment: _legacyTomorrowAdjustment,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );
    return List.unmodifiable(items);
  }

  bool get hasContent => promptItems.any((item) => item.hasAnswer);

  String get previewText {
    for (final item in promptItems) {
      final text = item.answerText?.trim();
      if (text != null && text.isNotEmpty) {
        return text.length <= 120 ? text : '${text.substring(0, 120)}…';
      }
    }
    return '无内容';
  }

  @Deprecated('Use promptItems as the Journal source of truth.')
  String? get mostImportantAccomplishment =>
      _answerFor(JournalPromptCatalog.accomplishmentKey);

  @Deprecated('Use promptItems as the Journal source of truth.')
  String? get mostDrainingEvent =>
      _answerFor(JournalPromptCatalog.drainingEventKey);

  @Deprecated('Use promptItems as the Journal source of truth.')
  String? get emotionSource =>
      _answerFor(JournalPromptCatalog.emotionSourceKey);

  @Deprecated('Use promptItems as the Journal source of truth.')
  String? get learning => _answerFor(JournalPromptCatalog.learningKey);

  @Deprecated('Use promptItems as the Journal source of truth.')
  String? get tomorrowAdjustment =>
      _answerFor(JournalPromptCatalog.tomorrowAdjustmentKey);

  int get answeredPromptCount =>
      promptItems.where((item) => item.hasAnswer).length;

  String? _answerFor(String stableKey) {
    for (final item in promptItems) {
      if (item.sourcePromptStableKey == stableKey) return item.answerText;
    }
    return null;
  }
}

List<JournalEntryPromptItem> _legacyItems({
  required String entryId,
  required String? mostImportantAccomplishment,
  required String? mostDrainingEvent,
  required String? emotionSource,
  required String? learning,
  required String? tomorrowAdjustment,
  required int createdAt,
  required int updatedAt,
}) {
  final answers = <String, String?>{
    JournalPromptCatalog.accomplishmentKey: mostImportantAccomplishment,
    JournalPromptCatalog.drainingEventKey: mostDrainingEvent,
    JournalPromptCatalog.emotionSourceKey: emotionSource,
    JournalPromptCatalog.learningKey: learning,
    JournalPromptCatalog.tomorrowAdjustmentKey: tomorrowAdjustment,
  };
  return [
    for (final prompt in JournalPromptCatalog.prompts)
      JournalEntryPromptItem(
        id: deterministicUuid(
          'journal-entry-prompt-item:$entryId:${prompt.stableKey}:1',
        ),
        sourcePromptId: null,
        sourcePromptStableKey: prompt.stableKey,
        sourcePromptVersion: 1,
        promptSource: JournalPromptSource.system,
        questionTextSnapshot: prompt.questionText,
        helperTextSnapshot: prompt.helperText,
        responseKind: JournalResponseKind.longText,
        displayOrder: prompt.displayOrder,
        answerText: answers[prompt.stableKey],
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
  ];
}
