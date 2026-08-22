import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/ai_coach/application/ai_chat_coordinator.dart';
import 'package:rebirth/features/ai_coach/data/local_ai_chat_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_conversation.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_input_assembler.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_consent_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_authorization.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_request_binding.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_usage_snapshot.dart';

void main() {
  late AppDatabase database;
  late LocalAiChatRepository repository;
  late _ChatGateway gateway;
  late _GenerationGateway generationGateway;
  late _BindingStore bindings;
  late AiChatCoordinator coordinator;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.bootstrapDao.bootstrap(createUnboundProfile: true);
    repository = LocalAiChatRepository(
      database: database,
      dateTimeService: DateTimeService(now: () => DateTime.utc(2026, 8, 21)),
    );
    gateway = _ChatGateway();
    generationGateway = _GenerationGateway();
    bindings = _BindingStore();
    coordinator = _coordinator(
      repository: repository,
      gateway: gateway,
      generationGateway: generationGateway,
      bindings: bindings,
    );
  });

  tearDown(() => database.close());

  test('local transaction failure never calls the Provider gateway', () async {
    final failing = _coordinator(
      repository: _FailingRepository(),
      gateway: gateway,
      generationGateway: generationGateway,
      bindings: bindings,
    );

    await expectLater(
      failing.send(userContent: 'hello', scopes: const {}),
      throwsA(isA<AiChatRepositoryException>()),
    );
    expect(gateway.sendCalls, 0);
  });

  test(
    'binding failure leaves a visible failed turn without Provider call',
    () async {
      bindings.failSave = true;

      final result = await coordinator.send(
        userContent: 'hello',
        scopes: const {},
      );
      final conversation = await repository.getConversation(result.threadId);

      expect(result.status, AiChatOperationStatus.failed);
      expect(result.failureCode, AiReportFailureCode.requestBindingFailed);
      expect(gateway.sendCalls, 0);
      expect(conversation?.messages.last.status, AiChatMessageStatus.failed);
    },
  );

  test(
    'rapid duplicate send is single-flight and calls Provider once',
    () async {
      final remote = Completer<AiChatRemoteResult>();
      gateway.onSend = (requestId, bundle) => remote.future;

      final first = coordinator.send(userContent: 'hello', scopes: const {});
      final second = coordinator.send(userContent: 'hello', scopes: const {});
      await _waitFor(() => gateway.sendCalls == 1);
      remote.complete(
        _completed(
          requestId: gateway.lastRequestId!,
          inputHash: gateway.lastBundle!.inputHash,
        ),
      );

      final results = await Future.wait([first, second]);
      expect(gateway.sendCalls, 1);
      expect(results[0].threadId, results[1].threadId);
      expect(results[0].assistantMessageId, results[1].assistantMessageId);
      expect(results[0].status, AiChatOperationStatus.completed);
    },
  );

  test(
    'network outcome unknown is recovered by status without resend',
    () async {
      gateway.onSend = (_, _) => throw const AiGenerationException(
        AiReportFailureCode.networkOutcomeUnknown,
      );

      final sent = await coordinator.send(
        userContent: 'hello',
        scopes: const {},
      );
      var conversation = await repository.getConversation(sent.threadId);
      final unresolved = conversation!.messages.last;
      expect(sent.status, AiChatOperationStatus.pendingRecovery);
      expect(unresolved.status, AiChatMessageStatus.outcomeUnknown);

      gateway.onStatus = (requestId, inputHash, promptVersion) async =>
          _completed(requestId: requestId, inputHash: inputHash);
      final recovered = await coordinator.recover(unresolved);
      conversation = await repository.getConversation(sent.threadId);

      expect(recovered.status, AiChatRecoveryStatus.completed);
      expect(gateway.sendCalls, 1);
      expect(gateway.statusCalls, 1);
      expect(conversation?.messages.last.status, AiChatMessageStatus.completed);
      expect(conversation?.messages.last.content, 'A grounded reply.');
    },
  );

  test('known failure retry uses a new request ID', () async {
    gateway.onSend = (requestId, bundle) async => AiChatRemoteResult(
      status: AiChatRemoteStatus.failed,
      requestId: requestId,
      inputHash: bundle.inputHash,
      promptVersion: AiChatInputContract.promptVersion,
      failureCode: AiReportFailureCode.providerTimeout,
    );
    final failed = await coordinator.send(
      userContent: 'hello',
      scopes: const {},
    );
    final firstRequestId = gateway.lastRequestId;

    gateway.onSend = (requestId, bundle) async =>
        _completed(requestId: requestId, inputHash: bundle.inputHash);
    final retried = await coordinator.retry(
      threadId: failed.threadId,
      scopes: const {},
    );
    final conversation = await repository.getConversation(failed.threadId);

    expect(failed.status, AiChatOperationStatus.failed);
    expect(retried.status, AiChatOperationStatus.completed);
    expect(gateway.sendCalls, 2);
    expect(gateway.lastRequestId, isNot(firstRequestId));
    expect(conversation?.messages, hasLength(3));
    expect(conversation?.messages[1].status, AiChatMessageStatus.failed);
    expect(conversation?.messages[2].status, AiChatMessageStatus.completed);
  });

  test('disabled usage rejects before any local chat write', () async {
    generationGateway.usage = const AiUsageSnapshot(
      availability: AiUsageAvailability.limitReached,
      enabled: true,
      dailyLimit: 4,
      used: 4,
      remaining: 0,
      resetsAtUtcMilliseconds: 1,
    );

    await expectLater(
      coordinator.send(userContent: 'hello', scopes: const {}),
      throwsA(
        isA<AiGenerationException>().having(
          (error) => error.code,
          'code',
          AiReportFailureCode.usageLimitReached,
        ),
      ),
    );
    expect(await repository.listThreads(), isEmpty);
    expect(gateway.sendCalls, 0);
  });
}

AiChatCoordinator _coordinator({
  required AiChatRepository repository,
  required _ChatGateway gateway,
  required _GenerationGateway generationGateway,
  required _BindingStore bindings,
}) {
  return AiChatCoordinator(
    gateway: gateway,
    generationGateway: generationGateway,
    inputAssembler: _InputAssembler(),
    repository: repository,
    consentRepository: _ConsentRepository(),
    sessionStore: _SessionStore(),
    bindings: bindings,
    dateTimeService: DateTimeService(now: () => DateTime.utc(2026, 8, 21)),
    currentEndpoint: 'https://alpha.example.test',
  );
}

AiChatRemoteResult _completed({
  required String requestId,
  required String inputHash,
}) {
  return AiChatRemoteResult(
    status: AiChatRemoteStatus.completed,
    requestId: requestId,
    inputHash: inputHash,
    promptVersion: AiChatInputContract.promptVersion,
    reply: 'A grounded reply.',
    safetyCategory: AiChatSafetyCategory.normal,
    provider: 'fake',
    model: 'fake-chat',
  );
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 20; attempt += 1) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Condition was not reached.');
}

final class _InputAssembler implements AiChatInputAssembler {
  @override
  Future<AiChatInputBundle> build({
    required List<AiChatMessage> conversationMessages,
    required Set<AiDataScope> scopes,
  }) async {
    final messages = conversationMessages
        .where(
          (message) =>
              message.status == AiChatMessageStatus.completed &&
              message.content.isNotEmpty,
        )
        .map(
          (message) =>
              AiChatPromptMessage(role: message.role, content: message.content),
        )
        .toList(growable: false);
    return AiChatInputBundle(
      periodStartDate: '2026-08-15',
      periodEndDate: '2026-08-21',
      scopes: scopes,
      messages: messages,
      sources: const [],
      canonicalPayload: const {
        'schema_version': 1,
        'request_type': 'coach_chat',
      },
      canonicalJson: '{}',
      inputHash: List.filled(64, 'a').join(),
    );
  }
}

final class _ChatGateway implements AiChatGateway {
  Future<AiChatRemoteResult> Function(String, AiChatInputBundle)? onSend;
  Future<AiChatRemoteResult> Function(String, String, String)? onStatus;
  int sendCalls = 0;
  int statusCalls = 0;
  String? lastRequestId;
  AiChatInputBundle? lastBundle;

  @override
  Future<AiChatRemoteResult> sendTurn({
    required String requestId,
    required AiChatInputBundle bundle,
  }) {
    sendCalls += 1;
    lastRequestId = requestId;
    lastBundle = bundle;
    final callback = onSend;
    return callback == null
        ? Future.value(
            _completed(requestId: requestId, inputHash: bundle.inputHash),
          )
        : callback(requestId, bundle);
  }

  @override
  Future<AiChatRemoteResult> getRequestStatus({
    required String requestId,
    required String inputHash,
    required String promptVersion,
  }) {
    statusCalls += 1;
    return onStatus!(requestId, inputHash, promptVersion);
  }
}

final class _GenerationGateway extends Fake implements AiGenerationGateway {
  AiUsageSnapshot usage = const AiUsageSnapshot(
    availability: AiUsageAvailability.available,
    enabled: true,
    dailyLimit: 4,
    used: 0,
    remaining: 4,
    resetsAtUtcMilliseconds: 1,
  );

  @override
  Future<AiGenerationCapabilities> getCapabilities() async {
    return AiGenerationCapabilities(
      enabled: true,
      provider: 'fake',
      providerLabel: 'Fake',
      model: 'fake-chat',
      supportedReportTypes: const ['daily_insight', 'weekly_report'],
      promptVersions: const ['daily-insight-v1', 'weekly-report-v1'],
      inputSchemaVersion: 1,
      outputSchemaVersion: 1,
      streaming: false,
      responseStorageRequested: false,
      chatContract: AiChatGenerationContract(
        requestType: 'coach_chat',
        promptVersion: 'coach-chat-v1',
        inputSchemaVersion: 1,
        outputSchemaVersion: 1,
        maximumMessages: 12,
        maximumMessageCharacters: 2000,
        maximumHistoryCharacters: 12000,
        maximumContextCharacters: 32000,
        supportedScopes: const [
          'growth_summary',
          'today_metrics',
          'health_metrics',
          'journal_reflections',
        ],
        streaming: false,
      ),
    );
  }

  @override
  Future<AiUsageSnapshot> getUsage({
    AiUsageScope scope = AiUsageScope.reports,
  }) async => usage;
}

final class _ConsentRepository extends Fake implements AiConsentRepository {
  @override
  Future<AiDataAuthorization> read() async =>
      AiDataAuthorization(enabled: true, consentAt: 1);
}

final class _SessionStore implements AuthSessionStore {
  AuthSession? session = const AuthSession(
    accessToken: 'runtime-token',
    refreshToken: 'runtime-refresh',
    user: AuthUser(id: 'cloud-user-a', displayName: 'A'),
  );

  @override
  Future<void> clear() async => session = null;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> save(AuthSession session) async => this.session = session;
}

final class _BindingStore implements AiGenerationRequestBindingStore {
  final Map<String, AiGenerationRequestBinding> values = {};
  bool failSave = false;

  @override
  Future<void> save(AiGenerationRequestBinding binding) async {
    if (failSave) throw StateError('binding write failed');
    values[binding.localReportId] = binding;
  }

  @override
  Future<AiGenerationRequestBinding?> read(String localReportId) async =>
      values[localReportId];

  @override
  Future<List<AiGenerationRequestBinding>> readAll() async =>
      values.values.toList(growable: false);

  @override
  Future<void> delete(String localReportId) async {
    values.remove(localReportId);
  }
}

final class _FailingRepository extends Fake implements AiChatRepository {
  @override
  Future<AiChatConversation?> getConversation(String threadId) async => null;

  @override
  Future<AiChatPendingTurn> createPendingTurn({
    String? threadId,
    required String userContent,
    required String requestId,
    required String promptVersion,
  }) {
    throw const AiChatRepositoryException('write_failed');
  }
}
