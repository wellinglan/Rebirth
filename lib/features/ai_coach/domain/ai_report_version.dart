import 'ai_coach_exception.dart';
import 'ai_report_metadata.dart';
import 'ai_report_status.dart';

final class AiReportVersion {
  AiReportVersion({
    required this.id,
    required this.reportId,
    required this.version,
    required this.status,
    required this.generationSource,
    required this.modelMetadataJson,
    required this.content,
    required this.sensitivity,
    required this.quality,
    required this.errorCode,
    required this.createdAt,
    required this.completedAt,
  }) {
    if (id.trim().isEmpty || reportId.trim().isEmpty || version <= 0) {
      throw const InvalidAiInputException('Invalid AI report version.');
    }
    if (status != AiReportStatus.completed && status != AiReportStatus.failed) {
      throw const InvalidAiInputException(
        'A stored AI report version must be terminal.',
      );
    }
    if (status == AiReportStatus.completed &&
        (content == null || content!.trim().isEmpty)) {
      throw const InvalidAiInputException(
        'A completed AI report version requires content.',
      );
    }
    if (status == AiReportStatus.failed &&
        (errorCode == null || errorCode!.trim().isEmpty)) {
      throw const InvalidAiInputException(
        'A failed AI report version requires an error code.',
      );
    }
  }

  final String id;
  final String reportId;
  final int version;
  final AiReportStatus status;
  final String generationSource;
  final String? modelMetadataJson;
  final String? content;
  final AiReportSensitivity sensitivity;
  final AiReportQuality quality;
  final String? errorCode;
  final int createdAt;
  final int? completedAt;
}
