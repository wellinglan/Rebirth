import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/ai_coach/application/ai_report_generation_coordinator.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report.dart';

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
        coordinator: ref.watch(aiReportGenerationCoordinatorProvider),
      );
    });

final class AiPendingRecoveryController {
  AiPendingRecoveryController({required this.coordinator});

  final AiReportGenerationCoordinator coordinator;
  final Set<String> _checking = {};

  Future<void> confirmServerNotFound(AiReport report) async {
    await coordinator.confirmServerNotFound(report);
  }

  Future<AiPendingRecoveryState> check(AiReport report) async {
    if (!_checking.add(report.id)) return AiPendingRecoveryState.checking;
    try {
      final result = await coordinator.recoverPending(report);
      return switch (result.status) {
        AiReportGenerationRecoveryStatus.processing =>
          AiPendingRecoveryState.processing,
        AiReportGenerationRecoveryStatus.networkUnknown =>
          AiPendingRecoveryState.networkUnknown,
        AiReportGenerationRecoveryStatus.endpointMismatch =>
          AiPendingRecoveryState.endpointMismatch,
        AiReportGenerationRecoveryStatus.accountMismatch =>
          AiPendingRecoveryState.accountMismatch,
        AiReportGenerationRecoveryStatus.missingBinding =>
          AiPendingRecoveryState.missingBinding,
        AiReportGenerationRecoveryStatus.serverNotFound =>
          AiPendingRecoveryState.serverNotFound,
        AiReportGenerationRecoveryStatus.completed =>
          AiPendingRecoveryState.completed,
        AiReportGenerationRecoveryStatus.failed =>
          AiPendingRecoveryState.failed,
        AiReportGenerationRecoveryStatus.outcomeUnknown =>
          AiPendingRecoveryState.outcomeUnknown,
        AiReportGenerationRecoveryStatus.resultExpired =>
          AiPendingRecoveryState.resultExpired,
      };
    } finally {
      _checking.remove(report.id);
    }
  }
}
