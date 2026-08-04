import 'ai_coach_exception.dart';
import 'ai_report_status.dart';

abstract final class AiReportLifecycle {
  static bool canTransition(AiReportStatus from, AiReportStatus to) {
    return switch (from) {
      AiReportStatus.draft =>
        to == AiReportStatus.generating || to == AiReportStatus.archived,
      AiReportStatus.generating || AiReportStatus.pending =>
        to == AiReportStatus.completed || to == AiReportStatus.failed,
      AiReportStatus.completed || AiReportStatus.failed =>
        to == AiReportStatus.generating || to == AiReportStatus.archived,
      AiReportStatus.archived => false,
    };
  }

  static void requireTransition(AiReportStatus from, AiReportStatus to) {
    if (!canTransition(from, to)) {
      throw InvalidAiReportTransitionException(
        from: from.databaseValue,
        to: to.databaseValue,
      );
    }
  }
}
