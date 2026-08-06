import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/ai_coach/application/ai_report_generation_coordinator.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_coach_input_bundle.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';

import 'ai_manual_generation_view_state.dart';
import 'ai_report_history_controller.dart';
import 'ai_request_preview_controller.dart';
import 'models/ai_insight_request_context.dart';

final aiManualGenerationControllerFamily = AsyncNotifierProvider.autoDispose
    .family<
      AiManualGenerationController,
      AiManualGenerationViewState,
      AiInsightRequestContext
    >(AiManualGenerationController.new);

final aiManualGenerationControllerProvider = aiManualGenerationControllerFamily(
  weeklyAiInsightRequestContext,
);

class AiManualGenerationController
    extends AsyncNotifier<AiManualGenerationViewState> {
  AiManualGenerationController(this.context);

  final AiInsightRequestContext context;
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
    try {
      if (!_bundleMatchesContext(bundle) || !_hasGeneratableData(bundle)) {
        throw const AiGenerationException(AiReportFailureCode.invalidInput);
      }
      final preview = ref
          .read(aiRequestPreviewControllerFamily(context))
          .asData
          ?.value;
      if (preview?.bundle?.inputHash != bundle.inputHash ||
          !_sameScopes(
            preview?.selectedScopes ?? const {},
            bundle.selection.scopes,
          )) {
        throw const AiGenerationException(AiReportFailureCode.invalidInput);
      }
      final unchanged = await ref
          .read(aiRequestPreviewControllerFamily(context).notifier)
          .verifyPreviewIntegrity(bundle);
      if (!unchanged) return null;
      final result = await ref
          .read(aiReportGenerationCoordinatorProvider)
          .prepare(bundle);
      if (result.status ==
          AiReportGenerationPreflightStatus.reusableCompleted) {
        _setIfMounted(
          AiManualGenerationViewState(
            phase: AiManualGenerationPhase.success,
            capabilities: result.capabilities,
            reportId: result.reportId,
          ),
        );
        return null;
      }
      if (result.status == AiReportGenerationPreflightStatus.failed) {
        throw AiGenerationException(
          result.failureCode ?? AiReportFailureCode.unknown,
        );
      }
      _setIfMounted(
        AiManualGenerationViewState(
          phase: AiManualGenerationPhase.ready,
          capabilities: result.capabilities,
        ),
      );
      return result.capabilities;
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
    final activeCapabilities = state.asData?.value.capabilities;
    try {
      if (!_bundleMatchesContext(bundle) || !_hasGeneratableData(bundle)) {
        throw const AiGenerationException(AiReportFailureCode.invalidInput);
      }
      final preview = ref
          .read(aiRequestPreviewControllerFamily(context))
          .asData
          ?.value;
      if (preview == null ||
          preview.bundle == null ||
          preview.bundle!.inputHash != bundle.inputHash ||
          !_sameScopes(preview.selectedScopes, bundle.selection.scopes)) {
        throw const AiGenerationException(AiReportFailureCode.invalidInput);
      }
      final unchanged = await ref
          .read(aiRequestPreviewControllerFamily(context).notifier)
          .verifyPreviewIntegrity(bundle);
      if (!unchanged) return null;
      _setIfMounted(
        AiManualGenerationViewState(
          phase: AiManualGenerationPhase.submitting,
          capabilities: activeCapabilities,
        ),
      );
      final result = await ref
          .read(aiReportGenerationCoordinatorProvider)
          .generate(bundle);
      if (ref.mounted) ref.invalidate(aiReportHistoryControllerProvider);
      final stillCurrent = ref.mounted && _isCurrentBundle(bundle);
      if (result.awaitingRecovery) {
        _setIfMounted(
          AiManualGenerationViewState(
            phase: AiManualGenerationPhase.pendingRecovery,
            capabilities: result.capabilities ?? activeCapabilities,
            reportId: result.reportId,
            failureCode: result.failureCode,
          ),
        );
        return AiManualGenerationOutcome(
          reportId: result.reportId,
          completed: false,
          awaitingRecovery: true,
        );
      }
      if (result.completed) {
        if (stillCurrent) {
          _setIfMounted(
            AiManualGenerationViewState(
              phase: AiManualGenerationPhase.success,
              capabilities: result.capabilities ?? activeCapabilities,
              reportId: result.reportId,
            ),
          );
        }
        return stillCurrent
            ? AiManualGenerationOutcome(
                reportId: result.reportId,
                completed: true,
              )
            : null;
      }
      _setIfMounted(
        AiManualGenerationViewState(
          phase: AiManualGenerationPhase.failure,
          capabilities: result.capabilities ?? activeCapabilities,
          reportId: result.reportId,
          failureCode: result.failureCode,
        ),
      );
      return AiManualGenerationOutcome(
        reportId: result.reportId,
        completed: false,
      );
    } on AiGenerationException catch (error) {
      _setIfMounted(
        AiManualGenerationViewState(
          phase: AiManualGenerationPhase.failure,
          capabilities: activeCapabilities,
          failureCode: error.code,
        ),
      );
      return null;
    } catch (_) {
      const code = AiReportFailureCode.unknown;
      _setIfMounted(
        AiManualGenerationViewState(
          phase: AiManualGenerationPhase.failure,
          capabilities: activeCapabilities,
          failureCode: code,
        ),
      );
      return null;
    } finally {
      _submissionStarted = false;
    }
  }

  Future<AiManualGenerationViewState> _loadCapabilities() async {
    final gateway = ref.read(aiGenerationGatewayProvider);
    final bundle = ref
        .read(aiRequestPreviewControllerFamily(context))
        .asData
        ?.value
        .bundle;
    try {
      if (bundle != null &&
          _bundleMatchesContext(bundle) &&
          _hasGeneratableData(bundle)) {
        final result = await ref
            .read(aiReportGenerationCoordinatorProvider)
            .prepare(bundle);
        if (result.status ==
            AiReportGenerationPreflightStatus.reusableCompleted) {
          return AiManualGenerationViewState(
            phase: AiManualGenerationPhase.success,
            capabilities: result.capabilities,
            reportId: result.reportId,
          );
        }
        if (result.status == AiReportGenerationPreflightStatus.failed) {
          return AiManualGenerationViewState(
            phase: AiManualGenerationPhase.failure,
            failureCode: result.failureCode ?? AiReportFailureCode.unknown,
          );
        }
        return AiManualGenerationViewState(
          phase: AiManualGenerationPhase.ready,
          capabilities: result.capabilities,
        );
      }
      final capabilities = await gateway.getCapabilities();
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

  bool _isCurrentBundle(AiCoachInputBundle bundle) {
    final current = ref
        .read(aiRequestPreviewControllerFamily(context))
        .asData
        ?.value;
    return current?.bundle?.inputHash == bundle.inputHash &&
        _sameScopes(
          current?.selectedScopes ?? const {},
          bundle.selection.scopes,
        );
  }

  bool _bundleMatchesContext(AiCoachInputBundle bundle) {
    if (bundle.reportType != context.reportType) return false;
    if (!context.isDaily) return true;
    return bundle.periodStartDate == context.targetDate &&
        bundle.periodEndDate == context.targetDate;
  }

  bool _hasGeneratableData(AiCoachInputBundle bundle) {
    return bundle.sources.isNotEmpty ||
        bundle.selection.scopes.contains(AiDataScope.growthSummary);
  }

  bool _sameScopes(Set<AiDataScope> left, Set<AiDataScope> right) {
    return left.length == right.length && left.containsAll(right);
  }

  void _setIfMounted(AiManualGenerationViewState value) {
    if (ref.mounted) state = AsyncData(value);
  }
}
