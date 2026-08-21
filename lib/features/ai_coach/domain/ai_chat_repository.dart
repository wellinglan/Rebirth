import 'ai_chat_conversation.dart';

abstract interface class AiChatRepository {
  Future<List<AiChatThread>> listThreads({bool includeArchived = false});

  Future<AiChatConversation?> getConversation(String threadId);

  Future<AiChatPendingTurn> createPendingTurn({
    String? threadId,
    required String userContent,
    required String requestId,
    required String promptVersion,
  });

  Future<AiChatMessage> createPendingRetry({
    required String threadId,
    required String requestId,
    required String promptVersion,
  });

  Future<void> completeAssistant({
    required String requestId,
    required String content,
    required AiChatSafetyCategory safetyCategory,
  });

  Future<void> markAssistantFailed({
    required String requestId,
    required String errorCode,
  });

  Future<void> markAssistantOutcomeUnknown({required String requestId});

  Future<AiChatMessage?> findAssistantByRequestId(String requestId);

  Future<List<AiChatMessage>> listRecoverableMessages();

  Future<void> archiveThread(String threadId);

  Future<void> deleteThread(String threadId);
}
