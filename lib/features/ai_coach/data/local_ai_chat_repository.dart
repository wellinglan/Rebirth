import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_conversation.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_repository.dart';
import 'package:uuid/uuid.dart';

final class LocalAiChatRepository implements AiChatRepository {
  const LocalAiChatRepository({
    required this.database,
    required this.dateTimeService,
    this.uuid = const Uuid(),
  });

  final db.AppDatabase database;
  final DateTimeService dateTimeService;
  final Uuid uuid;

  @override
  Future<List<AiChatThread>> listThreads({bool includeArchived = false}) async {
    final userId = await _activeUserId();
    final query = database.select(database.aiChatThreads)
      ..where(
        (row) =>
            row.userId.equals(userId) &
            (includeArchived ? const Constant(true) : row.archivedAt.isNull()),
      )
      ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]);
    return (await query.get()).map(_thread).toList(growable: false);
  }

  @override
  Future<AiChatConversation?> getConversation(String threadId) async {
    final userId = await _activeUserId();
    final thread = await _ownedThread(userId, threadId);
    if (thread == null) return null;
    final messages =
        await (database.select(database.aiChatMessages)
              ..where(
                (row) =>
                    row.threadId.equals(threadId) & row.userId.equals(userId),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.sequence)]))
            .get();
    return AiChatConversation(
      thread: _thread(thread),
      messages: messages.map(_message).toList(growable: false),
    );
  }

  @override
  Future<AiChatPendingTurn> createPendingTurn({
    String? threadId,
    required String userContent,
    required String requestId,
    required String promptVersion,
  }) async {
    final normalizedContent = _requiredText(userContent, maximum: 2000);
    final normalizedPrompt = _requiredText(promptVersion, maximum: 64);
    final userId = await _activeUserId();
    final now = dateTimeService.currentSnapshot().utcMilliseconds;
    final resolvedThreadId = threadId ?? uuid.v4();
    final userMessageId = uuid.v4();
    final assistantMessageId = uuid.v4();
    await database.transaction(() async {
      final existing = await _ownedThread(userId, resolvedThreadId);
      final nextSequence = existing == null
          ? 0
          : await _nextSequence(userId, resolvedThreadId);
      if (threadId == null) {
        await database
            .into(database.aiChatThreads)
            .insert(
              db.AiChatThreadsCompanion.insert(
                id: Value(resolvedThreadId),
                userId: userId,
                title: _localTitle(normalizedContent),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      } else if (existing == null || existing.archivedAt != null) {
        throw const AiChatRepositoryException('thread_unavailable');
      }
      await database
          .into(database.aiChatMessages)
          .insert(
            db.AiChatMessagesCompanion.insert(
              id: Value(userMessageId),
              threadId: resolvedThreadId,
              userId: userId,
              role: 'user',
              sequence: nextSequence,
              content: Value(normalizedContent),
              status: 'completed',
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await database
          .into(database.aiChatMessages)
          .insert(
            db.AiChatMessagesCompanion.insert(
              id: Value(assistantMessageId),
              threadId: resolvedThreadId,
              userId: userId,
              role: 'assistant',
              sequence: nextSequence + 1,
              requestId: Value(requestId),
              status: 'pending',
              promptVersion: Value(normalizedPrompt),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await (database.update(database.aiChatThreads)..where(
            (row) =>
                row.id.equals(resolvedThreadId) & row.userId.equals(userId),
          ))
          .write(db.AiChatThreadsCompanion(updatedAt: Value(now)));
    });
    final conversation = await getConversation(resolvedThreadId);
    if (conversation == null) {
      throw const AiChatRepositoryException('write_failed');
    }
    return AiChatPendingTurn(
      thread: conversation.thread,
      userMessage: conversation.messages.firstWhere(
        (message) => message.id == userMessageId,
      ),
      assistantMessage: conversation.messages.firstWhere(
        (message) => message.id == assistantMessageId,
      ),
    );
  }

  @override
  Future<AiChatMessage> createPendingRetry({
    required String threadId,
    required String requestId,
    required String promptVersion,
  }) async {
    final userId = await _activeUserId();
    final thread = await _ownedThread(userId, threadId);
    if (thread == null || thread.archivedAt != null) {
      throw const AiChatRepositoryException('thread_unavailable');
    }
    final now = dateTimeService.currentSnapshot().utcMilliseconds;
    final id = uuid.v4();
    final sequence = await _nextSequence(userId, threadId);
    await database.transaction(() async {
      await database
          .into(database.aiChatMessages)
          .insert(
            db.AiChatMessagesCompanion.insert(
              id: Value(id),
              threadId: threadId,
              userId: userId,
              role: 'assistant',
              sequence: sequence,
              requestId: Value(requestId),
              status: 'pending',
              promptVersion: Value(_requiredText(promptVersion, maximum: 64)),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await (database.update(database.aiChatThreads)..where(
            (row) => row.id.equals(threadId) & row.userId.equals(userId),
          ))
          .write(db.AiChatThreadsCompanion(updatedAt: Value(now)));
    });
    return (await findAssistantByRequestId(requestId))!;
  }

  @override
  Future<void> completeAssistant({
    required String requestId,
    required String content,
    required AiChatSafetyCategory safetyCategory,
  }) => _finishAssistant(
    requestId: requestId,
    status: AiChatMessageStatus.completed,
    content: _requiredText(content, maximum: 6000),
    safetyCategory: safetyCategory,
  );

  @override
  Future<void> markAssistantFailed({
    required String requestId,
    required String errorCode,
  }) => _finishAssistant(
    requestId: requestId,
    status: AiChatMessageStatus.failed,
    errorCode: _requiredText(errorCode, maximum: 80),
  );

  @override
  Future<void> markAssistantOutcomeUnknown({required String requestId}) =>
      _finishAssistant(
        requestId: requestId,
        status: AiChatMessageStatus.outcomeUnknown,
      );

  Future<void> _finishAssistant({
    required String requestId,
    required AiChatMessageStatus status,
    String? content,
    AiChatSafetyCategory? safetyCategory,
    String? errorCode,
  }) async {
    final userId = await _activeUserId();
    final existing = await _assistantRow(userId, requestId);
    if (existing == null || existing.status != 'pending') {
      throw const AiChatRepositoryException('message_not_pending');
    }
    final now = dateTimeService.currentSnapshot().utcMilliseconds;
    await database.transaction(() async {
      final changed =
          await (database.update(database.aiChatMessages)..where(
                (row) =>
                    row.id.equals(existing.id) &
                    row.userId.equals(userId) &
                    row.status.equals('pending'),
              ))
              .write(
                db.AiChatMessagesCompanion(
                  status: Value(_statusValue(status)),
                  content: Value(content ?? ''),
                  safetyCategory: Value(_safetyValue(safetyCategory)),
                  errorCode: Value(errorCode),
                  updatedAt: Value(
                    now < existing.createdAt ? existing.createdAt : now,
                  ),
                ),
              );
      if (changed != 1) {
        throw const AiChatRepositoryException('message_not_pending');
      }
      await (database.update(database.aiChatThreads)..where(
            (row) =>
                row.id.equals(existing.threadId) & row.userId.equals(userId),
          ))
          .write(db.AiChatThreadsCompanion(updatedAt: Value(now)));
    });
  }

  @override
  Future<AiChatMessage?> findAssistantByRequestId(String requestId) async {
    final userId = await _activeUserId();
    final row = await _assistantRow(userId, requestId);
    return row == null ? null : _message(row);
  }

  @override
  Future<List<AiChatMessage>> listRecoverableMessages() async {
    final userId = await _activeUserId();
    final rows =
        await (database.select(database.aiChatMessages)
              ..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.role.equals('assistant') &
                    row.status.isIn(const ['pending', 'outcome_unknown']),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.updatedAt)]))
            .get();
    return rows.map(_message).toList(growable: false);
  }

  @override
  Future<void> archiveThread(String threadId) async {
    final userId = await _activeUserId();
    final now = dateTimeService.currentSnapshot().utcMilliseconds;
    final changed =
        await (database.update(database.aiChatThreads)..where(
              (row) =>
                  row.id.equals(threadId) &
                  row.userId.equals(userId) &
                  row.archivedAt.isNull(),
            ))
            .write(
              db.AiChatThreadsCompanion(
                archivedAt: Value(now),
                updatedAt: Value(now),
              ),
            );
    if (changed != 1) {
      throw const AiChatRepositoryException('thread_unavailable');
    }
  }

  @override
  Future<void> deleteThread(String threadId) async {
    final userId = await _activeUserId();
    await database.transaction(() async {
      final changed =
          await (database.delete(database.aiChatThreads)..where(
                (row) => row.id.equals(threadId) & row.userId.equals(userId),
              ))
              .go();
      if (changed != 1) {
        throw const AiChatRepositoryException('thread_unavailable');
      }
    });
  }

  Future<String> _activeUserId() async =>
      (await database.bootstrapDao.bootstrap()).activeUserId;

  Future<db.AiChatThreadRow?> _ownedThread(String userId, String threadId) =>
      (database.select(database.aiChatThreads)..where(
            (row) => row.id.equals(threadId) & row.userId.equals(userId),
          ))
          .getSingleOrNull();

  Future<db.AiChatMessageRow?> _assistantRow(String userId, String requestId) =>
      (database.select(database.aiChatMessages)..where(
            (row) =>
                row.userId.equals(userId) &
                row.role.equals('assistant') &
                row.requestId.equals(requestId),
          ))
          .getSingleOrNull();

  Future<int> _nextSequence(String userId, String threadId) async {
    final maximum = database.aiChatMessages.sequence.max();
    final row =
        await (database.selectOnly(database.aiChatMessages)
              ..addColumns([maximum])
              ..where(
                database.aiChatMessages.userId.equals(userId) &
                    database.aiChatMessages.threadId.equals(threadId),
              ))
            .getSingle();
    return (row.read(maximum) ?? -1) + 1;
  }

  AiChatThread _thread(db.AiChatThreadRow row) => AiChatThread(
    id: row.id,
    title: row.title,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    archivedAt: row.archivedAt,
  );

  AiChatMessage _message(db.AiChatMessageRow row) => AiChatMessage(
    id: row.id,
    threadId: row.threadId,
    role: row.role == 'user' ? AiChatRole.user : AiChatRole.assistant,
    sequence: row.sequence,
    content: row.content,
    requestId: row.requestId,
    status: _status(row.status),
    promptVersion: row.promptVersion,
    safetyCategory: _safety(row.safetyCategory),
    errorCode: row.errorCode,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  String _requiredText(String value, {required int maximum}) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > maximum) {
      throw const AiChatRepositoryException('invalid_content');
    }
    return normalized;
  }

  String _localTitle(String content) {
    final singleLine = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    return singleLine.length <= 36
        ? singleLine
        : '${singleLine.substring(0, 36)}...';
  }
}

AiChatMessageStatus _status(String value) => switch (value) {
  'pending' => AiChatMessageStatus.pending,
  'completed' => AiChatMessageStatus.completed,
  'failed' => AiChatMessageStatus.failed,
  'outcome_unknown' => AiChatMessageStatus.outcomeUnknown,
  _ => throw StateError('Unsupported AI chat message status.'),
};

String _statusValue(AiChatMessageStatus value) => switch (value) {
  AiChatMessageStatus.pending => 'pending',
  AiChatMessageStatus.completed => 'completed',
  AiChatMessageStatus.failed => 'failed',
  AiChatMessageStatus.outcomeUnknown => 'outcome_unknown',
};

AiChatSafetyCategory? _safety(String? value) => switch (value) {
  null => null,
  'normal' => AiChatSafetyCategory.normal,
  'caution' => AiChatSafetyCategory.caution,
  'high_risk' => AiChatSafetyCategory.highRisk,
  _ => throw StateError('Unsupported AI chat safety category.'),
};

String? _safetyValue(AiChatSafetyCategory? value) => switch (value) {
  null => null,
  AiChatSafetyCategory.normal => 'normal',
  AiChatSafetyCategory.caution => 'caution',
  AiChatSafetyCategory.highRisk => 'high_risk',
};
