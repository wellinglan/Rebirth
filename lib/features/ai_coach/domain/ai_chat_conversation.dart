import 'dart:collection';

enum AiChatRole { user, assistant }

enum AiChatMessageStatus { pending, completed, failed, outcomeUnknown }

enum AiChatSafetyCategory { normal, caution, highRisk }

final class AiChatThread {
  const AiChatThread({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.archivedAt,
  });

  final String id;
  final String title;
  final int createdAt;
  final int updatedAt;
  final int? archivedAt;

  bool get isArchived => archivedAt != null;
}

final class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.threadId,
    required this.role,
    required this.sequence,
    required this.content,
    required this.requestId,
    required this.status,
    required this.promptVersion,
    required this.safetyCategory,
    required this.errorCode,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String threadId;
  final AiChatRole role;
  final int sequence;
  final String content;
  final String? requestId;
  final AiChatMessageStatus status;
  final String? promptVersion;
  final AiChatSafetyCategory? safetyCategory;
  final String? errorCode;
  final int createdAt;
  final int updatedAt;
}

final class AiChatConversation {
  AiChatConversation({
    required this.thread,
    required List<AiChatMessage> messages,
  }) : messages = UnmodifiableListView(messages);

  final AiChatThread thread;
  final List<AiChatMessage> messages;
}

final class AiChatPendingTurn {
  const AiChatPendingTurn({
    required this.thread,
    required this.userMessage,
    required this.assistantMessage,
  });

  final AiChatThread thread;
  final AiChatMessage userMessage;
  final AiChatMessage assistantMessage;
}

final class AiChatRepositoryException implements Exception {
  const AiChatRepositoryException(this.code);

  final String code;
}
