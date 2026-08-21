import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/ai_coach/data/local_ai_chat_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_conversation.dart';

void main() {
  late AppDatabase database;
  late DateTime now;
  late LocalAiChatRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    now = DateTime.utc(2026, 8, 21, 10);
    repository = LocalAiChatRepository(
      database: database,
      dateTimeService: DateTimeService(now: () => now),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'new turn stores user and pending assistant in one local thread',
    () async {
      final turn = await repository.createPendingTurn(
        userContent: '  今天想梳理一下接下来的安排。  ',
        requestId: '11111111-1111-4111-8111-111111111111',
        promptVersion: 'coach-chat-v1',
      );

      expect(turn.thread.title, '今天想梳理一下接下来的安排。');
      expect(turn.userMessage.content, '今天想梳理一下接下来的安排。');
      expect(turn.userMessage.status, AiChatMessageStatus.completed);
      expect(turn.assistantMessage.status, AiChatMessageStatus.pending);
      expect(turn.assistantMessage.content, isEmpty);
      expect(await database.select(database.aiChatThreads).get(), hasLength(1));
      expect(
        await database.select(database.aiChatMessages).get(),
        hasLength(2),
      );
    },
  );

  test('completed reply survives repository recreation', () async {
    final turn = await repository.createPendingTurn(
      userContent: '我今天有一点累。',
      requestId: '22222222-2222-4222-8222-222222222222',
      promptVersion: 'coach-chat-v1',
    );
    now = now.add(const Duration(minutes: 1));
    await repository.completeAssistant(
      requestId: turn.assistantMessage.requestId!,
      content: '  可以先留一点恢复空间，由你决定下一步。  ',
      safetyCategory: AiChatSafetyCategory.normal,
    );

    final recreated = LocalAiChatRepository(
      database: database,
      dateTimeService: DateTimeService(now: () => now),
    );
    final conversation = await recreated.getConversation(turn.thread.id);

    expect(conversation?.messages, hasLength(2));
    expect(conversation?.messages.last.content, '可以先留一点恢复空间，由你决定下一步。');
    expect(
      conversation?.messages.last.safetyCategory,
      AiChatSafetyCategory.normal,
    );
    expect(conversation?.messages.last.status, AiChatMessageStatus.completed);
  });

  test(
    'known failure keeps turn and retry receives a new request ID',
    () async {
      final turn = await repository.createPendingTurn(
        userContent: '帮我想一想。',
        requestId: '33333333-3333-4333-8333-333333333333',
        promptVersion: 'coach-chat-v1',
      );
      await repository.markAssistantFailed(
        requestId: turn.assistantMessage.requestId!,
        errorCode: 'provider_timeout',
      );
      final retry = await repository.createPendingRetry(
        threadId: turn.thread.id,
        requestId: '44444444-4444-4444-8444-444444444444',
        promptVersion: 'coach-chat-v1',
      );
      final conversation = await repository.getConversation(turn.thread.id);

      expect(conversation?.messages, hasLength(3));
      expect(conversation?.messages[1].status, AiChatMessageStatus.failed);
      expect(conversation?.messages[1].errorCode, 'provider_timeout');
      expect(retry.status, AiChatMessageStatus.pending);
      expect(retry.requestId, isNot(turn.assistantMessage.requestId));
    },
  );

  test('outcome unknown remains recoverable after recreation', () async {
    final turn = await repository.createPendingTurn(
      userContent: '检查恢复状态。',
      requestId: '55555555-5555-4555-8555-555555555555',
      promptVersion: 'coach-chat-v1',
    );
    await repository.markAssistantOutcomeUnknown(
      requestId: turn.assistantMessage.requestId!,
    );

    final recoverable = await repository.listRecoverableMessages();

    expect(recoverable, hasLength(1));
    expect(recoverable.single.status, AiChatMessageStatus.outcomeUnknown);
    expect(recoverable.single.requestId, turn.assistantMessage.requestId);
  });

  test('outcome unknown can become completed after status recovery', () async {
    final turn = await repository.createPendingTurn(
      userContent: '等待服务端结果。',
      requestId: '56565656-5656-4565-8565-565656565656',
      promptVersion: 'coach-chat-v1',
    );
    await repository.markAssistantOutcomeUnknown(
      requestId: turn.assistantMessage.requestId!,
    );

    await repository.completeAssistant(
      requestId: turn.assistantMessage.requestId!,
      content: '状态查询已找回回复。',
      safetyCategory: AiChatSafetyCategory.normal,
    );

    final recovered = await repository.findAssistantByRequestId(
      turn.assistantMessage.requestId!,
    );
    expect(recovered?.status, AiChatMessageStatus.completed);
    expect(recovered?.content, '状态查询已找回回复。');
  });

  test('archive hides thread but preserves messages', () async {
    final turn = await repository.createPendingTurn(
      userContent: '归档这个会话。',
      requestId: '66666666-6666-4666-8666-666666666666',
      promptVersion: 'coach-chat-v1',
    );
    await repository.archiveThread(turn.thread.id);

    expect(await repository.listThreads(), isEmpty);
    expect(
      (await repository.listThreads(includeArchived: true)).single.isArchived,
      isTrue,
    );
    expect(
      (await repository.getConversation(turn.thread.id))?.messages,
      hasLength(2),
    );
  });

  test('delete cascades all local messages', () async {
    final turn = await repository.createPendingTurn(
      userContent: '删除这个会话。',
      requestId: '77777777-7777-4777-8777-777777777777',
      promptVersion: 'coach-chat-v1',
    );

    await repository.deleteThread(turn.thread.id);

    expect(await database.select(database.aiChatThreads).get(), isEmpty);
    expect(await database.select(database.aiChatMessages).get(), isEmpty);
  });

  test(
    'active accounts cannot see or mutate each other conversations',
    () async {
      final accountA = await database.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      final turn = await repository.createPendingTurn(
        userContent: '账号 A 的私有会话。',
        requestId: '88888888-8888-4888-8888-888888888888',
        promptVersion: 'coach-chat-v1',
      );
      await (database.update(database.userProfiles)
            ..where((row) => row.id.equals(accountA.activeUserId)))
          .write(const UserProfilesCompanion(isActive: Value(false)));
      const accountB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
      await database
          .into(database.userProfiles)
          .insert(
            UserProfilesCompanion.insert(
              id: const Value(accountB),
              timezoneId: 'Etc/UTC',
            ),
          );
      await database
          .into(database.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              userId: accountB,
              localInstallationId: accountA.localInstallationId,
            ),
          );

      expect(await repository.listThreads(), isEmpty);
      expect(await repository.getConversation(turn.thread.id), isNull);
      await expectLater(
        repository.deleteThread(turn.thread.id),
        throwsA(isA<AiChatRepositoryException>()),
      );
      expect(await database.select(database.aiChatThreads).get(), hasLength(1));
    },
  );
}
