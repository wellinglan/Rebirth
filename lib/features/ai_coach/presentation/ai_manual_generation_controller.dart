import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_request_binding.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';

import 'ai_manual_generation_view_state.dart';
import 'ai_report_history_controller.dart';
import 'ai_request_preview_controller.dart';

final aiManualGenerationControllerProvider =
    AsyncNotifierProvider.autoDispose<
      AiManualGenerationController,
      AiManualGenerationViewState
    >(AiManualGenerationController.new);

class AiManualGenerationController
    extends AsyncNotifier<AiManualGenerationViewState> {
  bool _submissionStarted = false;
  bool _preflightStarted = false;

  @override
  Future<AiManualGenerationViewState> build() => _loadCapabilities();

  Future<void> reloadCapabilities() async {
    if (_submissionStarted) return;
    state = const AsyncLoading<AiManualGenerationViewState>();
    state = await AsyncValue.guard(_loadCapabilities);
  }

  Future<AiGenerationCapabilities?> prepareForConfirmation(
    AiCoachInputBundle bundle,
  ) async {
    if (_submissionStarted || _preflightStarted) return null;
    _preflightStarted = true;
    final consentRepository = ref.read(aiConsentRepositoryProvider);
    final sessionStore = ref.read(authSessionStoreProvider);
    final gateway = ref.read(aiGenerationGatewayProvider);
    final reports = ref.read(aiReportRepositoryProvider);
    try {
      final preview = ref
          .read(aiRequestPreviewControllerProvider)
          .asData
          ?.value;
      if (preview?.bundle?.inputHash != bundle.inputHash ||
          !_sameScopes(
            preview?.selectedScopes ?? const {},
            bundle.selection.scopes,
          )) {
        throw const AiGenerationException(AiReportFailureCode.invalidInput);
      }
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
      final capabilities = await gateway.getCapabilities();
      _validateCapabilities(capabilities, bundle);
      final reusable = await reports.findReusableCompleted(
        reportType: bundle.reportType,
        periodStartDate: bundle.periodStartDate,
        periodEndDate: bundle.periodEndDate,
        promptVersion: bundle.promptVersion,
        inputHash: bundle.inputHash,
      );
      if (reusable != null) {
        _setIfMounted(
          AiManualGenerationViewState(
            phase: AiManualGenerationPhase.success,
            capabilities: capabilities,
            reportId: reusable.id,
          ),
        );
        return null;
      }
      _setIfMounted(
        AiManualGenerationViewState(
          phase: AiManualGenerationPhase.ready,
          capabilities: capabilities,
        ),
      );
      return capabilities;
    } on AiGenerationException catch (error) {
      _setIfMounted(
        AiManualGenerationViewState(
          phase: AiManualGenerationPhase.failure,
          failureCode: error.code,
        ),
      );
      return null;
    } catch (_) {
      _setIfMounted(
        const AiManualGenerationViewState(
          phase: AiManualGenerationPhase.failure,
          failureCode: AiReportFailureCode.unknown,
        ),
      );
      return null;
    } finally {
      _preflightStarted = false;
    }
  }

  Future<AiManualGenerationOutcome?> submit(AiCoachInputBundle bundle) async {
    if (_submissionStarted) return null;
    _submissionStarted = true;
    final gateway = ref.read(aiGenerationGatewayProvider);
    final reports = ref.read(aiReportRepositoryProvider);
    final consentRepository = ref.read(aiConsentRepositoryProvider);
    final sessionStore = ref.read(authSessionStoreProvider);
    String? pendingId;
    AiGenerationCapabilities? activeCapabilities;
    try {
      final preview = ref
          .read(aiRequestPreviewControllerProvider)
          .asData
          ?.value;
      if (preview == null ||
          preview.bundle == null ||
          preview.bundle!.inputHash != bundle.inputHash ||
          !_sameScopes(preview.selectedScopes, bundle.selection.scopes)) {
        throw const AiGenerationException(AiReportFailureCode.invalidInput);
      }
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
      final capabilities = await gateway.getCapabilities();
      activeCapabilities = capabilities;
      _validateCapabilities(capabilities, bundle);
      final reusable = await reports.findReusableCompleted(
        reportType: bundle.reportType,
        periodStartDate: bundle.periodStartDate,
        periodEndDate: bundle.periodEndDate,
        promptVersion: bundle.promptVersion,
        inputHash: bundle.inputHash,
      );
      if (reusable != null) {
        _setIfMounted(
          AiManualGenerationViewState(
            phase: AiManualGenerationPhase.success,
            capabilities: capabilities,
            reportId: reusable.id,
          ),
        );
        return AiManualGenerationOutcome(
          reportId: reusable.id,
          completed: true,
        );
      }

      _setIfMounted(
        AiManualGenerationViewState(
          phase: AiManualGenerationPhase.submitting,
          capabilities: capabilities,
        ),
      );
      final pending = await reports.createPending(input: bundle);
      pendingId = pending.id;
      try {
        await ref
            .read(aiGenerationRequestBindingStoreProvider)
            .save(
              AiGenerationRequestBinding(
                localReportId: pending.id,
                requestId: pending.id,
                normalizedEndpoint: ref
                    .read(effectiveServerEndpointProvider)
                    .baseUrl,
                cloudUserId: session.user.id,
                inputHash: bundle.inputHash,
                reportType: bundle.reportType.databaseValue,
                promptVersion: bundle.promptVersion,
                createdAt: ref
                    .read(dateTimeServiceProvider)
                    .currentSnapshot()
                    .utcMilliseconds,
              ),
            );
      } catch (_) {
        await reports.markFailed(
          reportId: pending.id,
          errorCode: AiReportFailureCode.requestBindingFailed.databaseValue,
        );
        _setIfMounted(
          AiManualGenerationViewState(
            phase: AiManualGenerationPhase.failure,
            capabilities: activeCapabilities,
            reportId: pending.id,
            failureCode: AiReportFailureCode.requestBindingFailed,
          ),
        );
        return AiManualGenerationOutcome(
          reportId: pending.id,
          completed: false,
        );
      }
      final remote = await gateway.generateWeekly(
        requestId: pending.id,
        bundle: bundle,
      );
      if (remote.status == AiRemoteRequestStatus.processing) {
        _setIfMounted(
          AiManualGenerationViewState(
            phase: AiManualGenerationPhase.pendingRecovery,
            capabilities: capabilities,
            reportId: pending.id,
          ),
        );
        return AiManualGenerationOutcome(
          reportId: pending.id,
          completed: false,
          awaitingRecovery: true,
        );
      }
      if (remote.status == AiRemoteRequestStatus.outcomeUnknown ||
          remote.status == AiRemoteRequestStatus.resultExpired) {
        final code = remote.status == AiRemoteRequestStatus.outcomeUnknown
            ? AiReportFailureCode.outcomeUnknown
            : AiReportFailureCode.resultExpired;
        await reports.markFailed(
          reportId: pending.id,
          errorCode: code.databaseValue,
        );
        await _deleteBinding(pending.id);
        _setIfMounted(
          AiManualGenerationViewState(
            phase: AiManualGenerationPhase.failure,
            capabilities: capabilities,
            reportId: pending.id,
            failureCode: code,
          ),
        );
        return AiManualGenerationOutcome(
          reportId: pending.id,
          completed: false,
        );
      }
      if (remote.status == AiRemoteRequestStatus.failed) {
        final code = remote.failureCode ?? AiReportFailureCode.requestFailed;
        throw AiGenerationException(code);
      }
      final result = remote.completedResult!;
      await reports.markCompleted(
        reportId: pending.id,
        reportContent: result.reportContent,
        structuredOutputJson: result.structuredOutputJson,
        provider: result.provider,
        model: result.model,
      );
      await _deleteBinding(pending.id);
      if (ref.mounted) ref.invalidate(aiReportHistoryControllerProvider);
      final stillCurrent = ref.mounted && _isCurrentBundle(bundle);
      if (stillCurrent) {
        _setIfMounted(
          AiManualGenerationViewState(
            phase: AiManualGenerationPhase.success,
            capabilities: capabilities,
            reportId: pending.id,
          ),
        );
      }
      return stillCurrent
          ? AiManualGenerationOutcome(reportId: pending.id, completed: true)
          : null;
    } on AiGenerationException catch (error) {
      if (pendingId != null &&
          error.code == AiReportFailureCode.networkOutcomeUnknown) {
        _setIfMounted(
          AiManualGenerationViewState(
            phase: AiManualGenerationPhase.pendingRecovery,
            capabilities: activeCapabilities,
            reportId: pendingId,
            failureCode: error.code,
          ),
        );
        return AiManualGenerationOutcome(
          reportId: pendingId,
          completed: false,
          awaitingRecovery: true,
        );
      }
      if (pendingId != null) {
        try {
          await reports.markFailed(
            reportId: pendingId,
            errorCode: error.code.databaseValue,
          );
        } catch (_) {
          // The original controlled error remains the only UI-visible failure.
        }
        if (ref.mounted) ref.invalidate(aiReportHistoryControllerProvider);
        await _deleteBinding(pendingId);
      }
      _setIfMounted(
        AiManualGenerationViewState(
          phase: AiManualGenerationPhase.failure,
          capabilities: activeCapabilities,
          reportId: pendingId,
          failureCode: error.code,
        ),
      );
      return pendingId == null
          ? null
          : AiManualGenerationOutcome(reportId: pendingId, completed: false);
    } catch (_) {
      const code = AiReportFailureCode.unknown;
      if (pendingId != null) {
        try {
          await reports.markFailed(
            reportId: pendingId,
            errorCode: code.databaseValue,
          );
        } catch (_) {}
        if (ref.mounted) ref.invalidate(aiReportHistoryControllerProvider);
      }
      _setIfMounted(
        AiManualGenerationViewState(
          phase: AiManualGenerationPhase.failure,
          capabilities: activeCapabilities,
          reportId: pendingId,
          failureCode: code,
        ),
      );
      return pendingId == null
          ? null
          : AiManualGenerationOutcome(reportId: pendingId, completed: false);
    } finally {
      _submissionStarted = false;
    }
  }

  Future<AiManualGenerationViewState> _loadCapabilities() async {
    final gateway = ref.read(aiGenerationGatewayProvider);
    final bundle = ref
        .read(aiRequestPreviewControllerProvider)
        .asData
        ?.value
        .bundle;
    try {
      final capabilities = await gateway.getCapabilities();
      if (capabilities.enabled && bundle != null) {
        _validateCapabilities(capabilities, bundle);
      }
      return AiManualGenerationViewState(
        phase: capabilities.enabled
            ? AiManualGenerationPhase.ready
            : AiManualGenerationPhase.disabled,
        capabilities: capabilities,
      );
    } on AiGenerationException catch (error) {
      if (error.code == AiReportFailureCode.authenticationRequired) {
        return const AiManualGenerationViewState(
          phase: AiManualGenerationPhase.signedOut,
        );
      }
      return AiManualGenerationViewState(
        phase: AiManualGenerationPhase.failure,
        failureCode: error.code,
      );
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
    if (capabilities.reportContracts.isNotEmpty) {
      if (contract == null) {
        throw const AiGenerationException(
          AiReportFailureCode.unsupportedReportType,
        );
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
            1 ||
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

  bool _isCurrentBundle(AiCoachInputBundle bundle) {
    final current = ref.read(aiRequestPreviewControllerProvider).asData?.value;
    return current?.bundle?.inputHash == bundle.inputHash &&
        _sameScopes(
          current?.selectedScopes ?? const {},
          bundle.selection.scopes,
        );
  }

  bool _sameScopes(Set<AiDataScope> left, Set<AiDataScope> right) {
    return left.length == right.length && left.containsAll(right);
  }

  void _setIfMounted(AiManualGenerationViewState value) {
    if (ref.mounted) state = AsyncData(value);
  }

  Future<void> _deleteBinding(String reportId) async {
    try {
      await ref.read(aiGenerationRequestBindingStoreProvider).delete(reportId);
    } catch (_) {
      // A terminal local report is authoritative; stale metadata is harmless.
    }
  }
}
