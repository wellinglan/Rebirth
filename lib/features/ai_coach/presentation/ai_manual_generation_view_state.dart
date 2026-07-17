import 'package:rebirth/features/ai_coach/domain/ai_generation_gateway.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';

enum AiManualGenerationPhase {
  signedOut,
  disabled,
  ready,
  submitting,
  pendingRecovery,
  success,
  failure,
}

final class AiManualGenerationViewState {
  const AiManualGenerationViewState({
    required this.phase,
    this.capabilities,
    this.reportId,
    this.failureCode,
  });

  final AiManualGenerationPhase phase;
  final AiGenerationCapabilities? capabilities;
  final String? reportId;
  final AiReportFailureCode? failureCode;

  bool get isSubmitting => phase == AiManualGenerationPhase.submitting;
}

final class AiManualGenerationOutcome {
  const AiManualGenerationOutcome({
    required this.reportId,
    required this.completed,
    this.awaitingRecovery = false,
  });

  final String reportId;
  final bool completed;
  final bool awaitingRecovery;
}
