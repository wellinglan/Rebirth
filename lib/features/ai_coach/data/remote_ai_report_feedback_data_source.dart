import 'package:rebirth/core/network/api_client.dart';
import 'package:rebirth/features/account/data/auth_session_manager.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback_remote_data_source.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback_repository.dart';

final class RemoteAiReportFeedbackDataSource
    implements AiReportFeedbackRemoteDataSource {
  const RemoteAiReportFeedbackDataSource({
    required this.apiClient,
    required this.sessionManager,
  });

  final ApiClient apiClient;
  final AuthSessionManager sessionManager;

  @override
  Future<List<AiReportFeedbackRemoteRecord>> listAll() async {
    final json = await sessionManager.runAuthorized(
      (token) => apiClient.getJson('/ai/report-feedback', accessToken: token),
    );
    final items = json['items'];
    if (items is! List) throw const FormatException('Invalid feedback list.');
    return List.unmodifiable(
      items.map((item) {
        if (item is! Map) throw const FormatException('Invalid feedback item.');
        return _decode(Map<String, Object?>.from(item));
      }),
    );
  }

  @override
  Future<AiReportFeedbackMutationResult> upsert(AiReportFeedback feedback) =>
      _mutate('/ai/report-feedback/upsert', {
        'expected_server_version': feedback.serverVersion,
        'feedback_id': feedback.id,
        'helpfulness': feedback.helpfulness.databaseValue,
        'prompt_id': feedback.promptId,
        'prompt_version': feedback.promptVersion,
        'reason_codes': feedback.reasons.map((item) => item.code).toList(),
        'report_id': feedback.reportId,
        'report_type': feedback.reportType,
        'report_version': feedback.reportVersion,
      });

  @override
  Future<AiReportFeedbackMutationResult> delete(AiReportFeedback feedback) =>
      _mutate('/ai/report-feedback/delete', {
        'expected_server_version': feedback.serverVersion,
        'feedback_id': feedback.id,
        'report_id': feedback.reportId,
        'report_version': feedback.reportVersion,
      });

  Future<AiReportFeedbackMutationResult> _mutate(
    String path,
    Map<String, Object?> body,
  ) async {
    final json = await sessionManager.runAuthorized(
      (token) => apiClient.postJson(path, accessToken: token, body: body),
      canReplay: false,
    );
    final outcome = switch (json['outcome']) {
      'applied' => AiReportFeedbackMutationOutcome.applied,
      'conflict' => AiReportFeedbackMutationOutcome.conflict,
      _ => throw const FormatException('Invalid feedback outcome.'),
    };
    final item = json['item'];
    if (item is! Map) throw const FormatException('Invalid feedback item.');
    return AiReportFeedbackMutationResult(
      outcome: outcome,
      remote: _decode(Map<String, Object?>.from(item)),
    );
  }

  AiReportFeedbackRemoteRecord _decode(Map<String, Object?> json) {
    final reasons = json['reason_codes'];
    if (reasons is! List || reasons.any((item) => item is! String)) {
      throw const FormatException('Invalid feedback reasons.');
    }
    return AiReportFeedbackRemoteRecord(
      id: json['feedback_id'] as String,
      reportId: json['report_id'] as String,
      reportVersion: json['report_version'] as int,
      reportType: json['report_type'] as String,
      helpfulness: AiReportHelpfulness.fromDatabaseValue(
        json['helpfulness'] as String,
      ),
      reasons: reasons.cast<String>().map(AiReportFeedbackReason.fromCode),
      promptId: json['prompt_id'] as String,
      promptVersion: json['prompt_version'] as String,
      serverVersion: json['server_version'] as int,
      createdAt: json['created_at'] as int,
      updatedAt: json['updated_at'] as int,
      deletedAt: json['deleted_at'] as int?,
    );
  }
}
