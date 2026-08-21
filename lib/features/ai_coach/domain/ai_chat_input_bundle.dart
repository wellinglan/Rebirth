import 'dart:collection';

import 'ai_chat_conversation.dart';
import 'ai_coach_exception.dart';
import 'ai_data_scope.dart';
import 'ai_input_source_ref.dart';

abstract final class AiChatInputContract {
  static const schemaVersion = 1;
  static const requestType = 'coach_chat';
  static const promptVersion = 'coach-chat-v1';
  static const contextPeriodDays = 7;
  static const maximumMessages = 12;
  static const maximumMessageCharacters = 2000;
  static const maximumHistoryCharacters = 12000;
  static const maximumContextCharacters = 32000;

  static const supportedScopes = {
    AiDataScope.growthSummary,
    AiDataScope.todayMetrics,
    AiDataScope.healthMetrics,
    AiDataScope.journalReflections,
  };
}

final class AiChatPromptMessage {
  const AiChatPromptMessage({required this.role, required this.content});

  final AiChatRole role;
  final String content;

  Map<String, Object?> toCanonicalMap() => {
    'role': role == AiChatRole.user ? 'user' : 'assistant',
    'content': content,
  };
}

final class AiChatInputBundle {
  AiChatInputBundle({
    required this.periodStartDate,
    required this.periodEndDate,
    required Set<AiDataScope> scopes,
    required List<AiChatPromptMessage> messages,
    required List<AiInputSourceRef> sources,
    required Map<String, Object?> canonicalPayload,
    required this.canonicalJson,
    required this.inputHash,
  }) : scopes = Set<AiDataScope>.unmodifiable(scopes),
       messages = UnmodifiableListView(messages),
       sources = UnmodifiableListView(sources),
       canonicalPayload = _freezeMap(canonicalPayload) {
    if (periodStartDate.compareTo(periodEndDate) > 0 ||
        messages.isEmpty ||
        messages.length > AiChatInputContract.maximumMessages ||
        messages.first.role != AiChatRole.user ||
        messages.last.role != AiChatRole.user ||
        canonicalJson.isEmpty ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(inputHash)) {
      throw const InvalidAiInputException('Invalid AI chat input bundle.');
    }
    for (var index = 0; index < messages.length; index += 1) {
      final message = messages[index];
      if (message.content.trim().isEmpty ||
          message.content.length >
              AiChatInputContract.maximumMessageCharacters ||
          (index > 0 && messages[index - 1].role == message.role)) {
        throw const InvalidAiInputException('Invalid AI chat history.');
      }
    }
    if (messages.fold<int>(0, (sum, item) => sum + item.content.length) >
        AiChatInputContract.maximumHistoryCharacters) {
      throw const InvalidAiInputException('AI chat history is too large.');
    }
  }

  final String periodStartDate;
  final String periodEndDate;
  final Set<AiDataScope> scopes;
  final List<AiChatPromptMessage> messages;
  final List<AiInputSourceRef> sources;
  final Map<String, Object?> canonicalPayload;
  final String canonicalJson;
  final String inputHash;
}

Map<String, Object?> _freezeMap(Map<String, Object?> value) {
  return Map<String, Object?>.unmodifiable(
    value.map((key, item) => MapEntry(key, _freezeValue(item))),
  );
}

Object? _freezeValue(Object? value) {
  if (value is Map<String, Object?>) return _freezeMap(value);
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(value.map(_freezeValue));
  }
  return value;
}
