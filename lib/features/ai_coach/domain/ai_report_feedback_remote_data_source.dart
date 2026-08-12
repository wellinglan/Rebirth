import 'ai_report_feedback.dart';
import 'ai_report_feedback_repository.dart';

abstract interface class AiReportFeedbackRemoteDataSource {
  Future<List<AiReportFeedbackRemoteRecord>> listAll();

  Future<AiReportFeedbackMutationResult> upsert(AiReportFeedback feedback);

  Future<AiReportFeedbackMutationResult> delete(AiReportFeedback feedback);
}

enum AiReportFeedbackMutationOutcome { applied, conflict }

final class AiReportFeedbackMutationResult {
  const AiReportFeedbackMutationResult({
    required this.outcome,
    required this.remote,
  });

  final AiReportFeedbackMutationOutcome outcome;
  final AiReportFeedbackRemoteRecord remote;
}

final class AiReportFeedbackSyncSummary {
  const AiReportFeedbackSyncSummary({
    this.pushed = 0,
    this.pulled = 0,
    this.conflicts = 0,
    this.deferred = 0,
  });

  final int pushed;
  final int pulled;
  final int conflicts;
  final int deferred;
}

abstract interface class AiReportFeedbackSyncService {
  Future<AiReportFeedbackSyncSummary> synchronize();
}
