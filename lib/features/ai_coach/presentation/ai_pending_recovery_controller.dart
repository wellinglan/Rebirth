import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/core/config/server_endpoint_validator.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_request_binding.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';

enum AiPendingRecoveryState {
  awaitingCheck,
  checking,
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

final aiPendingRecoveryControllerProvider =
    Provider<AiPendingRecoveryController>((ref) {
      return AiPendingRecoveryController(
        gateway: ref.watch(aiGenerationGatewayProvider),
        reports: ref.watch(aiReportRepositoryProvider),
        bindings: ref.watch(aiGenerationRequestBindingStoreProvider),
        sessionStore: ref.watch(authSessionStoreProvider),
        currentEndpoint: ref.watch(effectiveServerEndpointProvider).baseUrl,
        endpointValidator: ref.watch(serverEndpointValidatorProvider),
      );
    });

final class AiPendingRecoveryController {
  AiPendingRecoveryController({
    required this.gateway,
    required this.reports,
    required this.bindings,
    required this.sessionStore,
    required this.currentEndpoint,
    required this.endpointValidator,
  });

  final AiGenerationGateway gateway;
  final AiReportRepository reports;
  final AiGenerationRequestBindingStore bindings;
  final AuthSessionStore sessionStore;
  final String currentEndpoint;
  final ServerEndpointValidator endpointValidator;
  final Set<String> _checking = {};

  Future<void> confirmServerNotFound(AiReport report) async {
    await reports.markFailed(
      reportId: report.id,
      errorCode: AiReportFailureCode.serverStateNotFound.databaseValue,
    );
    await bindings.delete(report.id);
  }

  Future<AiPendingRecoveryState> check(AiReport report) async {
    if (!_checking.add(report.id)) return AiPendingRecoveryState.checking;
    try {
      final binding = await bindings.read(report.id);
      if (binding == null) return AiPendingRecoveryState.missingBinding;
      if (endpointValidator.normalize(binding.normalizedEndpoint) !=
          endpointValidator.normalize(currentEndpoint)) {
        return AiPendingRecoveryState.endpointMismatch;
      }
      final session = await sessionStore.read();
      if (session == null || session.user.id != binding.cloudUserId) {
        return AiPendingRecoveryState.accountMismatch;
      }
      final result = await gateway.getRequestStatus(
        requestId: binding.requestId,
        inputHash: binding.inputHash,
        reportType: binding.reportType,
        promptVersion: binding.promptVersion,
      );
      switch (result.status) {
        case AiRemoteRequestStatus.completed:
          final completed = result.completedResult!;
          await reports.markCompleted(
            reportId: report.id,
            reportContent: completed.reportContent,
            structuredOutputJson: completed.structuredOutputJson,
            provider: completed.provider,
            model: completed.model,
          );
          await bindings.delete(report.id);
          return AiPendingRecoveryState.completed;
        case AiRemoteRequestStatus.failed:
          await reports.markFailed(
            reportId: report.id,
            errorCode: (result.failureCode ?? AiReportFailureCode.requestFailed)
                .databaseValue,
          );
          await bindings.delete(report.id);
          return AiPendingRecoveryState.failed;
        case AiRemoteRequestStatus.processing:
          return AiPendingRecoveryState.processing;
        case AiRemoteRequestStatus.outcomeUnknown:
          await reports.markFailed(
            reportId: report.id,
            errorCode: AiReportFailureCode.outcomeUnknown.databaseValue,
          );
          await bindings.delete(report.id);
          return AiPendingRecoveryState.outcomeUnknown;
        case AiRemoteRequestStatus.resultExpired:
          await reports.markFailed(
            reportId: report.id,
            errorCode: AiReportFailureCode.resultExpired.databaseValue,
          );
          await bindings.delete(report.id);
          return AiPendingRecoveryState.resultExpired;
        case AiRemoteRequestStatus.notFound:
          return AiPendingRecoveryState.serverNotFound;
      }
    } on AiGenerationException catch (error) {
      if (error.code == AiReportFailureCode.authenticationRequired) {
        return AiPendingRecoveryState.accountMismatch;
      }
      return AiPendingRecoveryState.networkUnknown;
    } catch (_) {
      return AiPendingRecoveryState.networkUnknown;
    } finally {
      _checking.remove(report.id);
    }
  }
}
