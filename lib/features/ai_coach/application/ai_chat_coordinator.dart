import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/core/config/server_endpoint_validator.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_conversation.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_input_assembler.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_chat_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_consent_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_request_binding.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_usage_snapshot.dart';
import 'package:uuid/uuid.dart';

final aiChatCoordinatorProvider = Provider<AiChatCoordinator>((ref) {
  return AiChatCoordinator(
    gateway: ref.watch(aiChatGatewayProvider),
    generationGateway: ref.watch(aiGenerationGatewayProvider),
    inputAssembler: ref.watch(aiChatInputAssemblerProvider),
    repository: ref.watch(aiChatRepositoryProvider),
    consentRepository: ref.watch(aiConsentRepositoryProvider),
    sessionStore: ref.watch(authSessionStoreProvider),
    bindings: ref.watch(aiGenerationRequestBindingStoreProvider),
    dateTimeService: ref.watch(dateTimeServiceProvider),
    currentEndpoint: ref.watch(effectiveServerEndpointProvider).baseUrl,
    endpointValidator: ref.watch(serverEndpointValidatorProvider),
  );
});

enum AiChatOperationStatus { completed, failed, pendingRecovery }

final class AiChatOperationResult {
  const AiChatOperationResult({
    required this.status,
    required this.threadId,
    required this.assistantMessageId,
    this.failureCode,
  });

  final AiChatOperationStatus status;
  final String threadId;
  final String assistantMessageId;
  final AiReportFailureCode? failureCode;
}

enum AiChatRecoveryStatus {
  processing,
  networkUnknown,
  endpointMismatch,
  accountMismatch,
  missingBinding,
  completed,
  failed,
  outcomeUnknown,
  resultExpired,
  serverNotFound,
}

final class AiChatRecoveryResult {
  const AiChatRecoveryResult({required this.status, this.failureCode});

  final AiChatRecoveryStatus status;
  final AiReportFailureCode? failureCode;
}

final class AiChatCoordinator {
  AiChatCoordinator({
    required this.gateway,
    required this.generationGateway,
    required this.inputAssembler,
    required this.repository,
    required this.consentRepository,
    required this.sessionStore,
    required this.bindings,
    required this.dateTimeService,
    required this.currentEndpoint,
    this.endpointValidator = const ServerEndpointValidator(),
    this.uuid = const Uuid(),
  });

  final AiChatGateway gateway;
  final AiGenerationGateway generationGateway;
  final AiChatInputAssembler inputAssembler;
  final AiChatRepository repository;
  final AiConsentRepository consentRepository;
  final AuthSessionStore sessionStore;
  final AiGenerationRequestBindingStore bindings;
  final DateTimeService dateTimeService;
  final String currentEndpoint;
  final ServerEndpointValidator endpointValidator;
  final Uuid uuid;
  final Map<String, Future<AiChatOperationResult>> _singleFlight = {};
  final Set<String> _recovering = {};

  Future<AiChatOperationResult> send({
    String? threadId,
    required String userContent,
    required Set<AiDataScope> scopes,
  }) {
    final key = threadId ?? '__new__';
    final existing = _singleFlight[key];
    if (existing != null) return existing;
    late final Future<AiChatOperationResult> operation;
    operation =
        _send(
          threadId: threadId,
          userContent: userContent,
          scopes: scopes,
        ).whenComplete(() {
          if (identical(_singleFlight[key], operation)) {
            _singleFlight.remove(key);
          }
        });
    _singleFlight[key] = operation;
    return operation;
  }

  Future<AiChatOperationResult> retry({
    required String threadId,
    required Set<AiDataScope> scopes,
  }) {
    final existing = _singleFlight[threadId];
    if (existing != null) return existing;
    late final Future<AiChatOperationResult> operation;
    operation = _retry(threadId: threadId, scopes: scopes).whenComplete(() {
      if (identical(_singleFlight[threadId], operation)) {
        _singleFlight.remove(threadId);
      }
    });
    _singleFlight[threadId] = operation;
    return operation;
  }

  Future<AiChatOperationResult> _send({
    required String? threadId,
    required String userContent,
    required Set<AiDataScope> scopes,
  }) async {
    final normalized = userContent.trim();
    if (normalized.isEmpty ||
        normalized.length > AiChatInputContract.maximumMessageCharacters) {
      throw const AiGenerationException(AiReportFailureCode.invalidInput);
    }
    final preflight = await _preflight(scopes);
    final existing = threadId == null
        ? null
        : await repository.getConversation(threadId);
    if (threadId != null && existing == null) {
      throw const AiGenerationException(AiReportFailureCode.invalidInput);
    }
    final latestAssistant = existing == null
        ? null
        : _latestAssistant(existing.messages);
    if (latestAssistant != null &&
        latestAssistant.status != AiChatMessageStatus.completed) {
      throw const AiGenerationException(AiReportFailureCode.invalidInput);
    }
    final previewMessages = [
      ...?existing?.messages,
      AiChatMessage(
        id: '__pending_user__',
        threadId: threadId ?? '__new__',
        role: AiChatRole.user,
        sequence: existing?.messages.length ?? 0,
        content: normalized,
        requestId: null,
        status: AiChatMessageStatus.completed,
        promptVersion: null,
        safetyCategory: null,
        errorCode: null,
        createdAt: 0,
        updatedAt: 0,
      ),
    ];
    final bundle = await inputAssembler.build(
      conversationMessages: previewMessages,
      scopes: scopes,
    );
    final requestId = uuid.v4();
    final pending = await repository.createPendingTurn(
      threadId: threadId,
      userContent: normalized,
      requestId: requestId,
      promptVersion: AiChatInputContract.promptVersion,
    );
    return _dispatch(pending: pending, bundle: bundle, preflight: preflight);
  }

  Future<AiChatOperationResult> _retry({
    required String threadId,
    required Set<AiDataScope> scopes,
  }) async {
    final preflight = await _preflight(scopes);
    final conversation = await repository.getConversation(threadId);
    if (conversation == null || conversation.thread.isArchived) {
      throw const AiGenerationException(AiReportFailureCode.invalidInput);
    }
    final latestAssistant = _latestAssistant(conversation.messages);
    if (latestAssistant == null ||
        latestAssistant.status != AiChatMessageStatus.failed) {
      throw const AiGenerationException(AiReportFailureCode.invalidInput);
    }
    final bundle = await inputAssembler.build(
      conversationMessages: conversation.messages,
      scopes: scopes,
    );
    final requestId = uuid.v4();
    final assistant = await repository.createPendingRetry(
      threadId: threadId,
      requestId: requestId,
      promptVersion: AiChatInputContract.promptVersion,
    );
    return _dispatch(
      pending: AiChatPendingTurn(
        thread: conversation.thread,
        userMessage: conversation.messages.lastWhere(
          (message) => message.role == AiChatRole.user,
        ),
        assistantMessage: assistant,
      ),
      bundle: bundle,
      preflight: preflight,
    );
  }

  Future<AiChatOperationResult> _dispatch({
    required AiChatPendingTurn pending,
    required AiChatInputBundle bundle,
    required _AiChatPreflight preflight,
  }) async {
    final assistant = pending.assistantMessage;
    try {
      await bindings.save(
        AiGenerationRequestBinding(
          localReportId: assistant.id,
          requestId: assistant.requestId!,
          normalizedEndpoint: preflight.normalizedEndpoint,
          cloudUserId: preflight.cloudUserId,
          inputHash: bundle.inputHash,
          reportType: AiChatInputContract.requestType,
          promptVersion: AiChatInputContract.promptVersion,
          createdAt: dateTimeService.currentSnapshot().utcMilliseconds,
        ),
      );
    } catch (_) {
      await repository.markAssistantFailed(
        requestId: assistant.requestId!,
        errorCode: AiReportFailureCode.requestBindingFailed.databaseValue,
      );
      return AiChatOperationResult(
        status: AiChatOperationStatus.failed,
        threadId: pending.thread.id,
        assistantMessageId: assistant.id,
        failureCode: AiReportFailureCode.requestBindingFailed,
      );
    }

    if (!await _sessionMatches(preflight.cloudUserId) ||
        !await _consentStillEnabled()) {
      await repository.markAssistantFailed(
        requestId: assistant.requestId!,
        errorCode: AiReportFailureCode.cancelled.databaseValue,
      );
      await _deleteBinding(assistant.id);
      return AiChatOperationResult(
        status: AiChatOperationStatus.failed,
        threadId: pending.thread.id,
        assistantMessageId: assistant.id,
        failureCode: AiReportFailureCode.cancelled,
      );
    }

    try {
      final remote = await gateway.sendTurn(
        requestId: assistant.requestId!,
        bundle: bundle,
      );
      if (!_matches(remote, bundle, assistant.requestId!)) {
        throw const AiGenerationException(AiReportFailureCode.responseInvalid);
      }
      return await _applyRemote(
        localMessageId: assistant.id,
        threadId: pending.thread.id,
        requestId: assistant.requestId!,
        remote: remote,
      );
    } on AiGenerationException catch (error) {
      if (error.code == AiReportFailureCode.networkOutcomeUnknown) {
        try {
          await repository.markAssistantOutcomeUnknown(
            requestId: assistant.requestId!,
          );
        } catch (_) {
          // The pending row and binding still allow an explicit status check.
        }
        return AiChatOperationResult(
          status: AiChatOperationStatus.pendingRecovery,
          threadId: pending.thread.id,
          assistantMessageId: assistant.id,
          failureCode: error.code,
        );
      }
      await _markFailedSafely(
        localMessageId: assistant.id,
        requestId: assistant.requestId!,
        code: error.code,
      );
      return AiChatOperationResult(
        status: AiChatOperationStatus.failed,
        threadId: pending.thread.id,
        assistantMessageId: assistant.id,
        failureCode: error.code,
      );
    } catch (_) {
      // The remote request may have completed. Keep its binding for an
      // explicit status check instead of issuing another Provider request.
      return AiChatOperationResult(
        status: AiChatOperationStatus.pendingRecovery,
        threadId: pending.thread.id,
        assistantMessageId: assistant.id,
        failureCode: AiReportFailureCode.outcomeUnknown,
      );
    }
  }

  Future<AiChatRecoveryResult> recover(AiChatMessage message) async {
    final requestId = message.requestId;
    if (message.role != AiChatRole.assistant ||
        requestId == null ||
        !_recovering.add(requestId)) {
      return const AiChatRecoveryResult(
        status: AiChatRecoveryStatus.processing,
      );
    }
    try {
      final binding = await bindings.read(message.id);
      if (binding == null || binding.requestId != requestId) {
        return const AiChatRecoveryResult(
          status: AiChatRecoveryStatus.missingBinding,
        );
      }
      if (endpointValidator.normalize(binding.normalizedEndpoint) !=
          endpointValidator.normalize(currentEndpoint)) {
        return const AiChatRecoveryResult(
          status: AiChatRecoveryStatus.endpointMismatch,
        );
      }
      if (!await _sessionMatches(binding.cloudUserId)) {
        return const AiChatRecoveryResult(
          status: AiChatRecoveryStatus.accountMismatch,
        );
      }
      final remote = await gateway.getRequestStatus(
        requestId: binding.requestId,
        inputHash: binding.inputHash,
        promptVersion: binding.promptVersion,
      );
      if (remote.requestId != binding.requestId ||
          remote.inputHash != binding.inputHash ||
          remote.promptVersion != binding.promptVersion) {
        await _markFailedSafely(
          localMessageId: message.id,
          requestId: requestId,
          code: AiReportFailureCode.responseInvalid,
        );
        return const AiChatRecoveryResult(
          status: AiChatRecoveryStatus.failed,
          failureCode: AiReportFailureCode.responseInvalid,
        );
      }
      final operation = await _applyRemote(
        localMessageId: message.id,
        threadId: message.threadId,
        requestId: requestId,
        remote: remote,
      );
      return AiChatRecoveryResult(
        status: switch (remote.status) {
          AiChatRemoteStatus.completed => AiChatRecoveryStatus.completed,
          AiChatRemoteStatus.failed => AiChatRecoveryStatus.failed,
          AiChatRemoteStatus.processing => AiChatRecoveryStatus.processing,
          AiChatRemoteStatus.outcomeUnknown =>
            AiChatRecoveryStatus.outcomeUnknown,
          AiChatRemoteStatus.resultExpired =>
            AiChatRecoveryStatus.resultExpired,
          AiChatRemoteStatus.notFound => AiChatRecoveryStatus.serverNotFound,
        },
        failureCode: operation.failureCode,
      );
    } on AiGenerationException catch (error) {
      return AiChatRecoveryResult(
        status: error.code == AiReportFailureCode.authenticationRequired
            ? AiChatRecoveryStatus.accountMismatch
            : AiChatRecoveryStatus.networkUnknown,
        failureCode: error.code,
      );
    } catch (_) {
      return const AiChatRecoveryResult(
        status: AiChatRecoveryStatus.networkUnknown,
      );
    } finally {
      _recovering.remove(requestId);
    }
  }

  Future<_AiChatPreflight> _preflight(Set<AiDataScope> scopes) async {
    final authorization = await consentRepository.read();
    if (!authorization.enabled) {
      throw const AiGenerationException(AiReportFailureCode.invalidInput);
    }
    final session = await sessionStore.read();
    if (session == null) {
      throw const AiGenerationException(
        AiReportFailureCode.authenticationRequired,
      );
    }
    final capabilities = await generationGateway.getCapabilities();
    _validateCapabilities(capabilities, scopes);
    final usage = await generationGateway.getUsage(scope: AiUsageScope.chat);
    switch (usage.availability) {
      case AiUsageAvailability.available:
        break;
      case AiUsageAvailability.disabled:
        throw const AiGenerationException(AiReportFailureCode.aiDisabled);
      case AiUsageAvailability.limitReached:
        throw const AiGenerationException(
          AiReportFailureCode.usageLimitReached,
        );
      case AiUsageAvailability.unknown:
        throw const AiGenerationException(AiReportFailureCode.requestFailed);
    }
    return _AiChatPreflight(
      cloudUserId: session.user.id,
      normalizedEndpoint: endpointValidator.normalize(currentEndpoint),
    );
  }

  void _validateCapabilities(
    AiGenerationCapabilities capabilities,
    Set<AiDataScope> scopes,
  ) {
    final contract = capabilities.chatContract;
    if (!capabilities.enabled) {
      throw const AiGenerationException(AiReportFailureCode.gatewayDisabled);
    }
    if (contract == null ||
        contract.requestType != AiChatInputContract.requestType ||
        contract.promptVersion != AiChatInputContract.promptVersion ||
        contract.inputSchemaVersion != AiChatInputContract.schemaVersion ||
        contract.outputSchemaVersion != 1 ||
        contract.maximumMessages < AiChatInputContract.maximumMessages ||
        contract.maximumMessageCharacters <
            AiChatInputContract.maximumMessageCharacters ||
        contract.maximumHistoryCharacters <
            AiChatInputContract.maximumHistoryCharacters ||
        contract.maximumContextCharacters <
            AiChatInputContract.maximumContextCharacters ||
        contract.streaming ||
        capabilities.streaming ||
        capabilities.responseStorageRequested ||
        !capabilities.durableRequestLedger ||
        !capabilities.requestStatusRecovery ||
        capabilities.exactlyOnceGuaranteed) {
      throw const AiGenerationException(AiReportFailureCode.invalidInput);
    }
    if (scopes.any(
      (scope) => !contract.supportedScopes.contains(scope.contractValue),
    )) {
      throw const AiGenerationException(AiReportFailureCode.unsupportedScope);
    }
  }

  Future<AiChatOperationResult> _applyRemote({
    required String localMessageId,
    required String threadId,
    required String requestId,
    required AiChatRemoteResult remote,
  }) async {
    switch (remote.status) {
      case AiChatRemoteStatus.completed:
        await repository.completeAssistant(
          requestId: requestId,
          content: remote.reply!,
          safetyCategory: remote.safetyCategory!,
        );
        await _deleteBinding(localMessageId);
        return AiChatOperationResult(
          status: AiChatOperationStatus.completed,
          threadId: threadId,
          assistantMessageId: localMessageId,
        );
      case AiChatRemoteStatus.processing:
        return AiChatOperationResult(
          status: AiChatOperationStatus.pendingRecovery,
          threadId: threadId,
          assistantMessageId: localMessageId,
        );
      case AiChatRemoteStatus.outcomeUnknown:
        final current = await repository.findAssistantByRequestId(requestId);
        if (current?.status == AiChatMessageStatus.pending) {
          await repository.markAssistantOutcomeUnknown(requestId: requestId);
        }
        return AiChatOperationResult(
          status: AiChatOperationStatus.pendingRecovery,
          threadId: threadId,
          assistantMessageId: localMessageId,
          failureCode: AiReportFailureCode.outcomeUnknown,
        );
      case AiChatRemoteStatus.failed:
        final code = remote.failureCode ?? AiReportFailureCode.requestFailed;
        await _markFailedSafely(
          localMessageId: localMessageId,
          requestId: requestId,
          code: code,
        );
        return AiChatOperationResult(
          status: AiChatOperationStatus.failed,
          threadId: threadId,
          assistantMessageId: localMessageId,
          failureCode: code,
        );
      case AiChatRemoteStatus.resultExpired:
      case AiChatRemoteStatus.notFound:
        final code = remote.status == AiChatRemoteStatus.resultExpired
            ? AiReportFailureCode.resultExpired
            : AiReportFailureCode.serverStateNotFound;
        await _markFailedSafely(
          localMessageId: localMessageId,
          requestId: requestId,
          code: code,
        );
        return AiChatOperationResult(
          status: AiChatOperationStatus.failed,
          threadId: threadId,
          assistantMessageId: localMessageId,
          failureCode: code,
        );
    }
  }

  AiChatMessage? _latestAssistant(List<AiChatMessage> messages) {
    for (final message in messages.reversed) {
      if (message.role == AiChatRole.assistant) return message;
    }
    return null;
  }

  bool _matches(
    AiChatRemoteResult remote,
    AiChatInputBundle bundle,
    String requestId,
  ) {
    return remote.requestId == requestId &&
        remote.inputHash == bundle.inputHash &&
        remote.promptVersion == AiChatInputContract.promptVersion;
  }

  Future<bool> _sessionMatches(String cloudUserId) async {
    final session = await sessionStore.read();
    return session != null && session.user.id == cloudUserId;
  }

  Future<bool> _consentStillEnabled() async {
    try {
      return (await consentRepository.read()).enabled;
    } catch (_) {
      return false;
    }
  }

  Future<void> _markFailedSafely({
    required String localMessageId,
    required String requestId,
    required AiReportFailureCode code,
  }) async {
    await repository.markAssistantFailed(
      requestId: requestId,
      errorCode: code.databaseValue,
    );
    await _deleteBinding(localMessageId);
  }

  Future<void> _deleteBinding(String localMessageId) async {
    try {
      await bindings.delete(localMessageId);
    } catch (_) {
      // Terminal local message state remains authoritative.
    }
  }
}

final class _AiChatPreflight {
  const _AiChatPreflight({
    required this.cloudUserId,
    required this.normalizedEndpoint,
  });

  final String cloudUserId;
  final String normalizedEndpoint;
}
