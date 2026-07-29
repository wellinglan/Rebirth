import 'dart:collection';

import 'package:rebirth/core/journal/journal_prompt_catalog.dart';

enum JournalPromptSource {
  system('system'),
  user('user'),
  futureAi('future_ai');

  const JournalPromptSource(this.wireName);

  final String wireName;

  static JournalPromptSource fromWireName(String value) => switch (value) {
    'system' => system,
    'user' => user,
    'future_ai' => futureAi,
    _ => throw ArgumentError.value(value, 'value', 'Unknown prompt source.'),
  };
}

enum JournalResponseKind {
  longText('long_text');

  const JournalResponseKind(this.wireName);

  final String wireName;

  static JournalResponseKind fromWireName(String value) => switch (value) {
    'long_text' => longText,
    _ => throw ArgumentError.value(value, 'value', 'Unknown response kind.'),
  };
}

final class JournalPromptDefinition {
  const JournalPromptDefinition({
    required this.id,
    required this.configurationId,
    required this.stableKey,
    required this.source,
    required this.questionText,
    required this.helperText,
    required this.responseKind,
    required this.displayOrder,
    required this.isEnabled,
    required this.promptVersion,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final String configurationId;
  final String? stableKey;
  final JournalPromptSource source;
  final String questionText;
  final String? helperText;
  final JournalResponseKind responseKind;
  final int displayOrder;
  final bool isEnabled;
  final int promptVersion;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  bool get isDeleted => deletedAt != null;

  bool get isSystem => source == JournalPromptSource.system;

  bool get isUser => source == JournalPromptSource.user;
}

final class JournalPromptConfiguration {
  JournalPromptConfiguration({
    required this.id,
    required this.userId,
    required this.logicalKey,
    required this.configurationVersion,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
    required this.serverVersion,
    required this.lastSyncedAt,
    required this.originDeviceId,
    required this.deletedAt,
    required List<JournalPromptDefinition> prompts,
  }) : prompts = UnmodifiableListView(
         List<JournalPromptDefinition>.of(prompts)
           ..sort(_comparePromptDefinitions),
       );

  final String id;
  final String userId;
  final String logicalKey;
  final int configurationVersion;
  final int createdAt;
  final int updatedAt;
  final String syncStatus;
  final int? serverVersion;
  final int? lastSyncedAt;
  final String? originDeviceId;
  final int? deletedAt;
  final List<JournalPromptDefinition> prompts;

  List<JournalPromptDefinition> get activePrompts => List.unmodifiable(
    prompts.where((prompt) => !prompt.isDeleted && prompt.isEnabled),
  );

  List<JournalPromptDefinition> get disabledPrompts => List.unmodifiable(
    prompts.where((prompt) => !prompt.isDeleted && !prompt.isEnabled),
  );

  int get activePromptCount => activePrompts.length;

  bool get isPending => syncStatus == 'pending' || syncStatus == 'local_only';
}

final class JournalPromptInput {
  const JournalPromptInput({required this.questionText, this.helperText});

  final String questionText;
  final String? helperText;
}

String normalizePromptText(String value, {required int maxLength}) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > maxLength) {
    throw const JournalPromptValidationException();
  }
  return normalized;
}

String? normalizeOptionalPromptText(String? value, {required int maxLength}) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized.length > maxLength) {
    throw const JournalPromptValidationException();
  }
  return normalized;
}

void validatePromptDefinition(JournalPromptDefinition prompt) {
  normalizePromptText(
    prompt.questionText,
    maxLength: JournalPromptLimits.questionTextLength,
  );
  normalizeOptionalPromptText(
    prompt.helperText,
    maxLength: JournalPromptLimits.helperTextLength,
  );
  if (prompt.promptVersion < 1 || prompt.displayOrder < 0) {
    throw const JournalPromptValidationException();
  }
  if (prompt.source == JournalPromptSource.system) {
    if (prompt.stableKey?.trim().isEmpty ?? true) {
      throw const JournalPromptValidationException();
    }
  } else if (prompt.stableKey != null) {
    throw const JournalPromptValidationException();
  }
  if (prompt.isDeleted && prompt.isEnabled) {
    throw const JournalPromptValidationException();
  }
}

int _comparePromptDefinitions(
  JournalPromptDefinition left,
  JournalPromptDefinition right,
) {
  final enabled = left.isEnabled == right.isEnabled
      ? 0
      : left.isEnabled
      ? -1
      : 1;
  if (enabled != 0) return enabled;
  final order = left.displayOrder.compareTo(right.displayOrder);
  return order != 0 ? order : left.id.compareTo(right.id);
}

final class JournalPromptValidationException implements Exception {
  const JournalPromptValidationException();

  @override
  String toString() => 'Journal prompt configuration is invalid.';
}

final class JournalPromptLimitException implements Exception {
  const JournalPromptLimitException();

  @override
  String toString() => 'Journal prompt limit reached.';
}

final class JournalPromptOperationException implements Exception {
  const JournalPromptOperationException();

  @override
  String toString() => 'Journal prompt operation is not allowed.';
}
