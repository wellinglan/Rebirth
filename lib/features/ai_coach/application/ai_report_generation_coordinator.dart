import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/core/config/server_endpoint_validator.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_consent_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_report_contract.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_request_binding.dart';
import 'package:rebirth/features/ai_coach/domain/ai_input_contract.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';

final aiReportGenerationCoordinatorProvider =
    Provider<AiReportGenerationCoordinator>((ref) {
      final endpoint = ref.watch(effectiveServerEndpointProvider).baseUrl;
      return AiReportGenerationCoordinator(
        gateway: ref.watch(aiGenerationGatewayProvider),
        reports: ref.watch(aiReportRepositoryProvider),
        consentRepository: ref.watch(aiConsentRepositoryProvider),
        sessionStore: ref.watch(authSessionStoreProvider),
        bindings: ref.watch(aiGenerationRequestBindingStoreProvider),
        dateTimeService: ref.watch(dateTimeServiceProvider),
        currentEndpoint: endpoint,
        endpointValidator: ref.watch(serverEndpointValidatorProvider),
      );
    });

enum AiReportGenerationPreflightStatus { ready, reusableCompleted, failed }

final class AiReportGenerationPreflightResult {
  const AiReportGenerationPreflightResult({
    required this.status,
    this.capabilities,
    this.reportId,
    this.failureCode,
  });

  final AiReportGenerationPreflightStatus status;
  final AiGenerationCapabilities? capabilities;
  final String? reportId;
  final AiReportFailureCode? failureCode;
}

enum AiReportGenerationResultStatus {
  reusableCompleted,
  completed,
  failed,
  pendingRecovery,
}

final class AiReportGenerationResult {
  const AiReportGenerationResult({
    required this.status,
    required this.reportId,
    this.capabilities,
    this.failureCode,
  });

  final AiReportGenerationResultStatus status;
  final String reportId;
  final AiGenerationCapabilities? capabilities;
  final AiReportFailureCode? failureCode;

  bool get completed =>
      status == AiReportGenerationResultStatus.completed ||
      status == AiReportGenerationResultStatus.reusableCompleted;

  bool get awaitingRecovery =>
      status == AiReportGenerationResultStatus.pendingRecovery;
}

enum AiReportGenerationRecoveryStatus {
  processing,
  networkUnknown,
  endpointMismatch,
  accountMismatch,
  missingBinding,
  serverNotFound,
  completed,
  failed,
  outcomeUnknown,
  resultExpired,
}

final class AiReportGenerationRecoveryResult {
  const AiReportGenerationRecoveryResult({
    required this.status,
    this.failureCode,
  });

  final AiReportGenerationRecoveryStatus status;
  final AiReportFailureCode? failureCode;
}

final class AiReportGenerationCoordinator {
  AiReportGenerationCoordinator({
    required this.gateway,
    required this.reports,
    required this.consentRepository,
    required this.sessionStore,
    required this.bindings,
    required this.dateTimeService,
    required this.currentEndpoint,
    this.endpointValidator = const ServerEndpointValidator(),
  });

  final AiGenerationGateway gateway;
  final AiReportRepository reports;
  final AiConsentRepository consentRepository;
  final AuthSessionStore sessionStore;
  final AiGenerationRequestBindingStore bindings;
  final DateTimeService dateTimeService;
  final String currentEndpoint;
  final ServerEndpointValidator endpointValidator;
  final Map<String, Future<AiReportGenerationResult>> _singleFlight = {};

  Future<AiReportGenerationPreflightResult> prepare(
    AiCoachInputBundle bundle,
  ) async {
    try {
      final preflight = await _preflight(bundle);
      if (preflight.reusable case final reusable?) {
        return AiReportGenerationPreflightResult(
          status: AiReportGenerationPreflightStatus.reusableCompleted,
          capabilities: preflight.capabilities,
          reportId: reusable.id,
        );
      }
      return AiReportGenerationPreflightResult(
        status: AiReportGenerationPreflightStatus.ready,
        capabilities: preflight.capabilities,
      );
    } on AiGenerationException catch (error) {
      return AiReportGenerationPreflightResult(
        status: AiReportGenerationPreflightStatus.failed,
        failureCode: error.code,
      );
    } catch (_) {
      return const AiReportGenerationPreflightResult(
        status: AiReportGenerationPreflightStatus.failed,
        failureCode: AiReportFailureCode.unknown,
      );
    }
  }

  Future<AiReportGenerationResult> generate(AiCoachInputBundle bundle) async {
    final preflight = await _preflight(bundle);
    final key = _singleFlightKey(bundle, preflight);
    final existing = _singleFlight[key];
    if (existing != null) return existing;
    late final Future<AiReportGenerationResult> operation;
    operation = _generateWithPreflight(bundle, preflight).whenComplete(() {
      if (identical(_singleFlight[key], operation)) {
        _singleFlight.remove(key);
      }
    });
    _singleFlight[key] = operation;
    return operation;
  }

  Future<AiReportGenerationRecoveryResult> recoverPending(
    AiReport report,
  ) async {
    try {
      final binding = await bindings.read(report.id);
      if (binding == null) {
        return const AiReportGenerationRecoveryResult(
          status: AiReportGenerationRecoveryStatus.missingBinding,
        );
      }
      final normalizedEndpoint = endpointValidator.normalize(currentEndpoint);
      if (endpointValidator.normalize(binding.normalizedEndpoint) !=
          normalizedEndpoint) {
        return const AiReportGenerationRecoveryResult(
          status: AiReportGenerationRecoveryStatus.endpointMismatch,
        );
      }
      if (!await _sessionMatches(binding.cloudUserId)) {
        return const AiReportGenerationRecoveryResult(
          status: AiReportGenerationRecoveryStatus.accountMismatch,
        );
      }
      final result = await gateway.getRequestStatus(
        requestId: binding.requestId,
        inputHash: binding.inputHash,
        reportType: binding.reportType,
        promptVersion: binding.promptVersion,
      );
      if (!_remoteMatchesBinding(result, binding)) {
        return await _markRecoveredFailure(
          report.id,
          AiReportFailureCode.responseInvalid,
        );
      }
      return _applyRecoveredResult(report.id, result);
    } on AiGenerationException catch (error) {
      if (error.code == AiReportFailureCode.authenticationRequired) {
        return const AiReportGenerationRecoveryResult(
          status: AiReportGenerationRecoveryStatus.accountMismatch,
        );
      }
      return const AiReportGenerationRecoveryResult(
        status: AiReportGenerationRecoveryStatus.networkUnknown,
      );
    } catch (_) {
      return const AiReportGenerationRecoveryResult(
        status: AiReportGenerationRecoveryStatus.networkUnknown,
      );
    }
  }

  Future<void> confirmServerNotFound(AiReport report) async {
    await reports.markFailed(
      reportId: report.id,
      errorCode: AiReportFailureCode.serverStateNotFound.databaseValue,
    );
    await bindings.delete(report.id);
  }

  Future<_GenerationPreflight> _preflight(AiCoachInputBundle bundle) async {
    _validateBundle(bundle);
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
    final normalizedEndpoint = endpointValidator.normalize(currentEndpoint);
    final endpointHash = _endpointHash(normalizedEndpoint);
    final capabilities = await gateway.getCapabilities();
    _validateCapabilities(capabilities, bundle);
    final reusable = await reports.findReusableCompleted(
      reportType: bundle.reportType,
      periodStartDate: bundle.periodStartDate,
      periodEndDate: bundle.periodEndDate,
      promptVersion: bundle.promptVersion,
      inputHash: bundle.inputHash,
      generationEndpointHash: endpointHash,
    );
    return _GenerationPreflight(
      capabilities: capabilities,
      cloudUserId: session.user.id,
      normalizedEndpoint: normalizedEndpoint,
      endpointHash: endpointHash,
      reusable: reusable,
    );
  }

  Future<AiReportGenerationResult> _generateWithPreflight(
    AiCoachInputBundle bundle,
    _GenerationPreflight preflight,
  ) async {
    if (preflight.reusable case final reusable?) {
      return AiReportGenerationResult(
        status: AiReportGenerationResultStatus.reusableCompleted,
        capabilities: preflight.capabilities,
        reportId: reusable.id,
      );
    }

    String? pendingId;
    try {
      final pending = await reports.createPending(
        input: bundle,
        generationEndpointHash: preflight.endpointHash,
      );
      pendingId = pending.id;
      try {
        await bindings.save(
          AiGenerationRequestBinding(
            localReportId: pending.id,
            requestId: pending.id,
            normalizedEndpoint: preflight.normalizedEndpoint,
            cloudUserId: preflight.cloudUserId,
            inputHash: bundle.inputHash,
            reportType: bundle.reportType.databaseValue,
            promptVersion: bundle.promptVersion,
            createdAt: dateTimeService.currentSnapshot().utcMilliseconds,
          ),
        );
      } catch (_) {
        await reports.markFailed(
          reportId: pending.id,
          errorCode: AiReportFailureCode.requestBindingFailed.databaseValue,
        );
        return AiReportGenerationResult(
          status: AiReportGenerationResultStatus.failed,
          capabilities: preflight.capabilities,
          reportId: pending.id,
          failureCode: AiReportFailureCode.requestBindingFailed,
        );
      }

      if (!await _sessionMatches(preflight.cloudUserId) ||
          !await _consentStillEnabled()) {
        return AiReportGenerationResult(
          status: AiReportGenerationResultStatus.pendingRecovery,
          capabilities: preflight.capabilities,
          reportId: pending.id,
        );
      }
      final remote = await _generateRemote(
        requestId: pending.id,
        bundle: bundle,
      );
      if (!_remoteMatchesBundle(
        remote,
        requestId: pending.id,
        bundle: bundle,
      )) {
        throw const AiGenerationException(AiReportFailureCode.responseInvalid);
      }
      if (!await _sessionMatches(preflight.cloudUserId) ||
          !await _consentStillEnabled()) {
        return AiReportGenerationResult(
          status: AiReportGenerationResultStatus.pendingRecovery,
          capabilities: preflight.capabilities,
          reportId: pending.id,
        );
      }
      return _applyGeneratedResult(
        pending.id,
        remote,
        capabilities: preflight.capabilities,
      );
    } on AiGenerationException catch (error) {
      if (pendingId != null &&
          error.code == AiReportFailureCode.networkOutcomeUnknown) {
        return AiReportGenerationResult(
          status: AiReportGenerationResultStatus.pendingRecovery,
          capabilities: preflight.capabilities,
          reportId: pendingId,
          failureCode: error.code,
        );
      }
      if (pendingId != null) {
        try {
          await reports.markFailed(
            reportId: pendingId,
            errorCode: error.code.databaseValue,
          );
        } catch (_) {
          // Keep the original controlled failure as the UI-visible result.
        }
        await _deleteBinding(pendingId);
        return AiReportGenerationResult(
          status: AiReportGenerationResultStatus.failed,
          capabilities: preflight.capabilities,
          reportId: pendingId,
          failureCode: error.code,
        );
      }
      rethrow;
    } catch (_) {
      if (pendingId != null) {
        try {
          await reports.markFailed(
            reportId: pendingId,
            errorCode: AiReportFailureCode.unknown.databaseValue,
          );
        } catch (_) {}
        await _deleteBinding(pendingId);
        return AiReportGenerationResult(
          status: AiReportGenerationResultStatus.failed,
          capabilities: preflight.capabilities,
          reportId: pendingId,
          failureCode: AiReportFailureCode.unknown,
        );
      }
      rethrow;
    }
  }

  Future<AiReportGenerationResult> _applyGeneratedResult(
    String reportId,
    AiRemoteRequestResult remote, {
    required AiGenerationCapabilities capabilities,
  }) async {
    switch (remote.status) {
      case AiRemoteRequestStatus.processing:
        return AiReportGenerationResult(
          status: AiReportGenerationResultStatus.pendingRecovery,
          capabilities: capabilities,
          reportId: reportId,
        );
      case AiRemoteRequestStatus.outcomeUnknown:
      case AiRemoteRequestStatus.resultExpired:
        final code = remote.status == AiRemoteRequestStatus.outcomeUnknown
            ? AiReportFailureCode.outcomeUnknown
            : AiReportFailureCode.resultExpired;
        await reports.markFailed(
          reportId: reportId,
          errorCode: code.databaseValue,
        );
        await _deleteBinding(reportId);
        return AiReportGenerationResult(
          status: AiReportGenerationResultStatus.failed,
          capabilities: capabilities,
          reportId: reportId,
          failureCode: code,
        );
      case AiRemoteRequestStatus.failed:
        final code = remote.failureCode ?? AiReportFailureCode.requestFailed;
        await reports.markFailed(
          reportId: reportId,
          errorCode: code.databaseValue,
        );
        await _deleteBinding(reportId);
        return AiReportGenerationResult(
          status: AiReportGenerationResultStatus.failed,
          capabilities: capabilities,
          reportId: reportId,
          failureCode: code,
        );
      case AiRemoteRequestStatus.completed:
        final completed = remote.completedResult!;
        await reports.markCompleted(
          reportId: reportId,
          reportContent: completed.reportContent,
          structuredOutputJson: completed.structuredOutputJson,
          provider: completed.provider,
          model: completed.model,
        );
        await _deleteBinding(reportId);
        return AiReportGenerationResult(
          status: AiReportGenerationResultStatus.completed,
          capabilities: capabilities,
          reportId: reportId,
        );
      case AiRemoteRequestStatus.notFound:
        return AiReportGenerationResult(
          status: AiReportGenerationResultStatus.pendingRecovery,
          capabilities: capabilities,
          reportId: reportId,
        );
    }
  }

  Future<AiReportGenerationRecoveryResult> _applyRecoveredResult(
    String reportId,
    AiRemoteRequestResult result,
  ) async {
    switch (result.status) {
      case AiRemoteRequestStatus.completed:
        final completed = result.completedResult!;
        await reports.markCompleted(
          reportId: reportId,
          reportContent: completed.reportContent,
          structuredOutputJson: completed.structuredOutputJson,
          provider: completed.provider,
          model: completed.model,
        );
        await _deleteBinding(reportId);
        return const AiReportGenerationRecoveryResult(
          status: AiReportGenerationRecoveryStatus.completed,
        );
      case AiRemoteRequestStatus.failed:
        final code = result.failureCode ?? AiReportFailureCode.requestFailed;
        await reports.markFailed(
          reportId: reportId,
          errorCode: code.databaseValue,
        );
        await _deleteBinding(reportId);
        return AiReportGenerationRecoveryResult(
          status: AiReportGenerationRecoveryStatus.failed,
          failureCode: code,
        );
      case AiRemoteRequestStatus.processing:
        return const AiReportGenerationRecoveryResult(
          status: AiReportGenerationRecoveryStatus.processing,
        );
      case AiRemoteRequestStatus.outcomeUnknown:
        return _markRecoveredFailure(
          reportId,
          AiReportFailureCode.outcomeUnknown,
        );
      case AiRemoteRequestStatus.resultExpired:
        return _markRecoveredFailure(
          reportId,
          AiReportFailureCode.resultExpired,
        );
      case AiRemoteRequestStatus.notFound:
        return const AiReportGenerationRecoveryResult(
          status: AiReportGenerationRecoveryStatus.serverNotFound,
        );
    }
  }

  Future<AiReportGenerationRecoveryResult> _markRecoveredFailure(
    String reportId,
    AiReportFailureCode code,
  ) async {
    await reports.markFailed(reportId: reportId, errorCode: code.databaseValue);
    await _deleteBinding(reportId);
    return AiReportGenerationRecoveryResult(
      status: switch (code) {
        AiReportFailureCode.outcomeUnknown =>
          AiReportGenerationRecoveryStatus.outcomeUnknown,
        AiReportFailureCode.resultExpired =>
          AiReportGenerationRecoveryStatus.resultExpired,
        _ => AiReportGenerationRecoveryStatus.failed,
      },
      failureCode: code,
    );
  }

  Future<AiRemoteRequestResult> _generateRemote({
    required String requestId,
    required AiCoachInputBundle bundle,
  }) {
    return switch (bundle.reportType) {
      AiReportType.dailyInsight => gateway.generateDaily(
        requestId: requestId,
        bundle: bundle,
      ),
      AiReportType.weeklyReport => gateway.generateWeekly(
        requestId: requestId,
        bundle: bundle,
      ),
      _ => throw const AiGenerationException(
        AiReportFailureCode.unsupportedReportType,
      ),
    };
  }

  void _validateBundle(AiCoachInputBundle bundle) {
    if (!AiInputContract.isSupportedReportType(bundle.reportType)) {
      throw const AiGenerationException(
        AiReportFailureCode.unsupportedReportType,
      );
    }
    if (bundle.promptVersion.trim().isEmpty) {
      throw const AiGenerationException(
        AiReportFailureCode.unsupportedPromptVersion,
      );
    }
    if (!_hasGeneratableData(bundle)) {
      throw const AiGenerationException(AiReportFailureCode.invalidInput);
    }
    final expectedScopes = AiInputContract.supportedScopesFor(
      bundle.reportType,
    );
    if (bundle.selection.scopes.any(
      (scope) => !expectedScopes.contains(scope),
    )) {
      throw const AiGenerationException(AiReportFailureCode.unsupportedScope);
    }
    if (bundle.reportType == AiReportType.dailyInsight &&
        bundle.periodStartDate != bundle.periodEndDate) {
      throw const AiGenerationException(AiReportFailureCode.invalidInput);
    }
  }

  void _validateCapabilities(
    AiGenerationCapabilities capabilities,
    AiCoachInputBundle bundle,
  ) {
    if (!capabilities.enabled) {
      throw const AiGenerationException(AiReportFailureCode.gatewayDisabled);
    }
    final contract = capabilities.contractFor(bundle.reportType.databaseValue);
    if (bundle.reportType == AiReportType.dailyInsight && contract == null) {
      throw const AiGenerationException(
        AiReportFailureCode.unsupportedReportType,
      );
    }
    if (capabilities.reportContracts.isNotEmpty) {
      if (contract == null) {
        throw const AiGenerationException(
          AiReportFailureCode.unsupportedReportType,
        );
      }
      final expectedPeriodKind = switch (bundle.reportType) {
        AiReportType.dailyInsight => AiReportPeriodKind.singleDay,
        AiReportType.weeklyReport => AiReportPeriodKind.sevenDays,
        _ => throw const AiGenerationException(
          AiReportFailureCode.unsupportedReportType,
        ),
      };
      if (contract.periodKind != expectedPeriodKind) {
        throw const AiGenerationException(AiReportFailureCode.invalidInput);
      }
      if (!contract.supportsPrompt(bundle.promptVersion)) {
        throw const AiGenerationException(
          AiReportFailureCode.unsupportedPromptVersion,
        );
      }
      if (bundle.selection.scopes.any(
        (scope) => !contract.supportedScopes.contains(scope.contractValue),
      )) {
        throw const AiGenerationException(AiReportFailureCode.unsupportedScope);
      }
    } else {
      if (!capabilities.supportedReportTypes.contains(
        bundle.reportType.databaseValue,
      )) {
        throw const AiGenerationException(
          AiReportFailureCode.unsupportedReportType,
        );
      }
      if (!capabilities.promptVersions.contains(bundle.promptVersion)) {
        throw const AiGenerationException(
          AiReportFailureCode.unsupportedPromptVersion,
        );
      }
    }
    if ((contract?.inputSchemaVersion ?? capabilities.inputSchemaVersion) !=
            AiInputContract.schemaVersion ||
        (contract?.outputSchemaVersion ?? capabilities.outputSchemaVersion) !=
            1 ||
        capabilities.streaming ||
        capabilities.responseStorageRequested ||
        !capabilities.durableRequestLedger ||
        !capabilities.requestStatusRecovery ||
        capabilities.exactlyOnceGuaranteed) {
      throw const AiGenerationException(AiReportFailureCode.invalidInput);
    }
  }

  bool _hasGeneratableData(AiCoachInputBundle bundle) {
    return bundle.sources.isNotEmpty ||
        bundle.selection.scopes.contains(AiDataScope.growthSummary);
  }

  bool _remoteMatchesBundle(
    AiRemoteRequestResult result, {
    required String requestId,
    required AiCoachInputBundle bundle,
  }) {
    return result.requestId == requestId &&
        result.inputHash == bundle.inputHash &&
        result.reportType == bundle.reportType.databaseValue &&
        result.promptVersion == bundle.promptVersion;
  }

  bool _remoteMatchesBinding(
    AiRemoteRequestResult result,
    AiGenerationRequestBinding binding,
  ) {
    return result.requestId == binding.requestId &&
        result.inputHash == binding.inputHash &&
        result.reportType == binding.reportType &&
        result.promptVersion == binding.promptVersion;
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

  Future<void> _deleteBinding(String reportId) async {
    try {
      await bindings.delete(reportId);
    } catch (_) {
      // Terminal local report state is authoritative; stale metadata is ignored.
    }
  }

  String _singleFlightKey(
    AiCoachInputBundle bundle,
    _GenerationPreflight preflight,
  ) {
    final scopes =
        bundle.selection.scopes
            .map((scope) => scope.contractValue)
            .toList(growable: false)
          ..sort();
    return [
      preflight.cloudUserId,
      preflight.endpointHash,
      bundle.reportType.databaseValue,
      bundle.periodStartDate,
      bundle.periodEndDate,
      bundle.promptVersion,
      bundle.inputHash,
      scopes.join(','),
    ].join('|');
  }

  String _endpointHash(String normalizedEndpoint) {
    final bytes = utf8.encode(
      'rebirth-ai-generation-endpoint:$normalizedEndpoint',
    );
    return sha256.convert(bytes).toString();
  }
}

final class _GenerationPreflight {
  const _GenerationPreflight({
    required this.capabilities,
    required this.cloudUserId,
    required this.normalizedEndpoint,
    required this.endpointHash,
    required this.reusable,
  });

  final AiGenerationCapabilities capabilities;
  final String cloudUserId;
  final String normalizedEndpoint;
  final String endpointHash;
  final AiReport? reusable;
}
