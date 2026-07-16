import 'ai_coach_exception.dart';
import 'ai_generation_mode.dart';
import 'ai_input_source_ref.dart';
import 'ai_report_status.dart';
import 'ai_report_type.dart';

final class AiReport {
  AiReport({
    required this.id,
    required this.userId,
    required this.reportType,
    required this.periodStartDate,
    required this.periodEndDate,
    required List<AiInputSourceRef> inputSources,
    required this.inputHash,
    required this.promptVersion,
    required this.provider,
    required this.model,
    required this.generationMode,
    required this.status,
    required this.reportContent,
    required this.structuredOutputJson,
    required this.errorCode,
    required this.requestedAt,
    required this.generatedAt,
    required this.createdAt,
    required this.updatedAt,
  }) : inputSources = List<AiInputSourceRef>.unmodifiable(inputSources) {
    if (id.trim().isEmpty || userId.trim().isEmpty) {
      throw const InvalidAiInputException('Invalid AI report identity.');
    }
    if (status == AiReportStatus.completed &&
        ((reportContent?.trim().isEmpty ?? true) || generatedAt == null)) {
      throw const InvalidAiInputException(
        'A completed AI report requires content and completion time.',
      );
    }
    if (status == AiReportStatus.failed &&
        (errorCode == null || !AiReportFailureCode.isSupported(errorCode!))) {
      throw const InvalidAiInputException(
        'A failed AI report requires a controlled error code.',
      );
    }
    if (status == AiReportStatus.pending && generatedAt != null) {
      throw const InvalidAiInputException(
        'A pending AI report cannot have a completion time.',
      );
    }
  }

  final String id;
  final String userId;
  final AiReportType reportType;
  final String periodStartDate;
  final String periodEndDate;
  final List<AiInputSourceRef> inputSources;
  final String inputHash;
  final String promptVersion;
  final String? provider;
  final String? model;
  final AiGenerationMode generationMode;
  final AiReportStatus status;
  final String? reportContent;
  final String? structuredOutputJson;
  final String? errorCode;
  final int requestedAt;
  final int? generatedAt;
  final int createdAt;
  final int updatedAt;
}
