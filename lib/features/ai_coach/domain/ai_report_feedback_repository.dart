import 'ai_report_feedback.dart';

abstract interface class AiReportFeedbackRepository {
  Future<AiReportFeedback?> getForVersion({
    required String reportId,
    required int reportVersion,
  });

  Future<AiReportFeedback> save({
    required String reportId,
    required int reportVersion,
    required AiReportHelpfulness helpfulness,
    Iterable<AiReportFeedbackReason> reasons = const [],
  });

  Future<void> clear({required String reportId, required int reportVersion});

  Future<List<AiReportFeedback>> listPending();

  Future<List<AiReportFeedback>> listAllForActiveAccount();

  Future<void> applyRemote(AiReportFeedbackRemoteRecord remote);

  Future<void> markSynced({
    required String id,
    required int serverVersion,
    required int serverUpdatedAt,
  });

  Future<void> markConflict({
    required String id,
    required AiReportFeedbackRemoteSnapshot remote,
  });

  Future<void> adoptRemote(String id);

  Future<void> keepLocal(String id);
}

final class AiReportFeedbackRemoteRecord {
  AiReportFeedbackRemoteRecord({
    required this.id,
    required this.reportId,
    required this.reportVersion,
    required this.reportType,
    required this.helpfulness,
    required Iterable<AiReportFeedbackReason> reasons,
    required this.promptId,
    required this.promptVersion,
    required this.serverVersion,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  }) : reasons = List.unmodifiable(reasons);

  final String id;
  final String reportId;
  final int reportVersion;
  final String reportType;
  final AiReportHelpfulness helpfulness;
  final List<AiReportFeedbackReason> reasons;
  final String promptId;
  final String promptVersion;
  final int serverVersion;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  AiReportFeedbackRemoteSnapshot get snapshot => AiReportFeedbackRemoteSnapshot(
    id: id,
    helpfulness: helpfulness,
    reasons: reasons,
    serverVersion: serverVersion,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );
}

final class AiReportFeedbackNotAllowedException implements Exception {
  const AiReportFeedbackNotAllowedException();
}
