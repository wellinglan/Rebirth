import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_coach/application/ai_chat_coordinator.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_conversation.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_chat_controller.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_chat_view_state.dart';

void main() {
  test(
    'send exposes the user turn before the server operation completes',
    () async {
      final repository = _ChatRepository();
      final operations = _ChatOperations();
      final container = ProviderContainer(
        overrides: [
          aiChatRepositoryProvider.overrideWithValue(repository),
          aiChatCoordinatorProvider.overrideWithValue(operations),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        aiChatControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(aiChatControllerProvider.future);

      final result = container
          .read(aiChatControllerProvider.notifier)
          .send('  这条消息应立即显示  ');
      final optimistic = container.read(aiChatControllerProvider).requireValue;

      expect(optimistic.interaction, AiChatInteraction.sending);
      expect(optimistic.conversation?.messages, hasLength(2));
      expect(optimistic.conversation?.messages.first.content, '这条消息应立即显示');
      expect(optimistic.conversation?.messages.first.role, AiChatRole.user);
      expect(
        optimistic.conversation?.messages.last.status,
        AiChatMessageStatus.pending,
      );
      expect(operations.completer.isCompleted, isFalse);

      repository.conversation = _completedConversation();
      operations.completer.complete(
        const AiChatOperationResult(
          status: AiChatOperationStatus.completed,
          threadId: 'thread-1',
          assistantMessageId: 'assistant-1',
        ),
      );

      expect(await result, isTrue);
      final completed = container.read(aiChatControllerProvider).requireValue;
      expect(completed.interaction, AiChatInteraction.ready);
      expect(completed.conversation?.messages.last.content, '服务器回复');
      expect(
        completed.conversation?.messages.last.status,
        AiChatMessageStatus.completed,
      );
    },
  );

  test('preflight rejection rolls back the optimistic conversation', () async {
    final repository = _ChatRepository();
    final operations = _ChatOperations();
    final container = ProviderContainer(
      overrides: [
        aiChatRepositoryProvider.overrideWithValue(repository),
        aiChatCoordinatorProvider.overrideWithValue(operations),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      aiChatControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(aiChatControllerProvider.future);

    final result = container
        .read(aiChatControllerProvider.notifier)
        .send('保留失败前的输入');
    expect(
      container
          .read(aiChatControllerProvider)
          .requireValue
          .conversation
          ?.messages,
      hasLength(2),
    );

    operations.completer.completeError(
      const AiGenerationException(AiReportFailureCode.providerUnavailable),
    );

    expect(await result, isFalse);
    final rolledBack = container.read(aiChatControllerProvider).requireValue;
    expect(rolledBack.interaction, AiChatInteraction.ready);
    expect(rolledBack.conversation, isNull);
    expect(rolledBack.failureCode, AiReportFailureCode.providerUnavailable);
  });
}

final class _ChatOperations implements AiChatOperations {
  final Completer<AiChatOperationResult> completer = Completer();

  @override
  Future<AiChatOperationResult> send({
    String? threadId,
    required String userContent,
    required Set<AiDataScope> scopes,
  }) => completer.future;

  @override
  Future<AiChatOperationResult> retry({
    required String threadId,
    required Set<AiDataScope> scopes,
  }) => throw UnimplementedError();

  @override
  Future<AiChatRecoveryResult> recover(AiChatMessage message) =>
      throw UnimplementedError();
}

final class _ChatRepository extends Fake implements AiChatRepository {
  AiChatConversation? conversation;

  @override
  Future<List<AiChatThread>> listThreads({
    bool includeArchived = false,
  }) async => conversation == null ? const [] : [conversation!.thread];

  @override
  Future<AiChatConversation?> getConversation(String threadId) async =>
      conversation?.thread.id == threadId ? conversation : null;
}

AiChatConversation _completedConversation() {
  const thread = AiChatThread(
    id: 'thread-1',
    title: '这条消息应立即显示',
    createdAt: 1,
    updatedAt: 2,
    archivedAt: null,
  );
  return AiChatConversation(
    thread: thread,
    messages: const [
      AiChatMessage(
        id: 'user-1',
        threadId: 'thread-1',
        role: AiChatRole.user,
        sequence: 0,
        content: '这条消息应立即显示',
        requestId: null,
        status: AiChatMessageStatus.completed,
        promptVersion: null,
        safetyCategory: null,
        errorCode: null,
        createdAt: 1,
        updatedAt: 1,
      ),
      AiChatMessage(
        id: 'assistant-1',
        threadId: 'thread-1',
        role: AiChatRole.assistant,
        sequence: 1,
        content: '服务器回复',
        requestId: 'request-1',
        status: AiChatMessageStatus.completed,
        promptVersion: 'coach-chat-v1',
        safetyCategory: AiChatSafetyCategory.normal,
        errorCode: null,
        createdAt: 2,
        updatedAt: 2,
      ),
    ],
  );
}
