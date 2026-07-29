import 'package:rebirth/core/journal/journal_prompt_catalog.dart';

import 'journal_prompt.dart';

final class JournalEntryPromptItem {
  const JournalEntryPromptItem({
    required this.id,
    required this.sourcePromptId,
    required this.sourcePromptStableKey,
    required this.sourcePromptVersion,
    required this.promptSource,
    required this.questionTextSnapshot,
    required this.helperTextSnapshot,
    required this.responseKind,
    required this.displayOrder,
    required this.answerText,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? sourcePromptId;
  final String? sourcePromptStableKey;
  final int sourcePromptVersion;
  final JournalPromptSource promptSource;
  final String questionTextSnapshot;
  final String? helperTextSnapshot;
  final JournalResponseKind responseKind;
  final int displayOrder;
  final String? answerText;
  final int createdAt;
  final int updatedAt;

  bool get hasAnswer => answerText?.trim().isNotEmpty ?? false;

  JournalEntryPromptItem copyWith({
    String? answerText,
    bool clearAnswer = false,
    int? displayOrder,
    int? updatedAt,
  }) {
    return JournalEntryPromptItem(
      id: id,
      sourcePromptId: sourcePromptId,
      sourcePromptStableKey: sourcePromptStableKey,
      sourcePromptVersion: sourcePromptVersion,
      promptSource: promptSource,
      questionTextSnapshot: questionTextSnapshot,
      helperTextSnapshot: helperTextSnapshot,
      responseKind: responseKind,
      displayOrder: displayOrder ?? this.displayOrder,
      answerText: clearAnswer ? null : answerText ?? this.answerText,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

void validateJournalPromptItems(List<JournalEntryPromptItem> items) {
  if (items.isEmpty || items.length > JournalPromptLimits.totalPromptCount) {
    throw const JournalPromptItemValidationException();
  }
  final ids = <String>{};
  final snapshots = <String>{};
  var hasAnswer = false;
  for (final item in items) {
    if (!ids.add(item.id) ||
        item.sourcePromptVersion < 1 ||
        item.displayOrder < 0 ||
        item.questionTextSnapshot.trim().isEmpty ||
        item.questionTextSnapshot.length >
            JournalPromptLimits.questionTextLength ||
        (item.helperTextSnapshot?.length ?? 0) >
            JournalPromptLimits.helperTextLength ||
        item.responseKind != JournalResponseKind.longText) {
      throw const JournalPromptItemValidationException();
    }
    final sourceId = item.sourcePromptId;
    if (sourceId != null &&
        !snapshots.add('$sourceId:${item.sourcePromptVersion}')) {
      throw const JournalPromptItemValidationException();
    }
    final answer = item.answerText?.trim();
    if (answer != null && answer.isNotEmpty) {
      if (answer.length > JournalPromptLimits.answerTextLength) {
        throw const JournalPromptItemValidationException();
      }
      hasAnswer = true;
    }
  }
  if (!hasAnswer) throw const JournalPromptItemValidationException();
}

final class JournalPromptItemValidationException implements Exception {
  const JournalPromptItemValidationException();

  @override
  String toString() => 'Journal prompt responses are invalid.';
}
