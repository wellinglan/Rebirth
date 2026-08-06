import 'ai_coach_input_bundle.dart';
import 'ai_report.dart';
import 'ai_report_metadata.dart';
import 'ai_report_type.dart';
import 'ai_report_version.dart';

abstract interface class AiReportRepository {
  Future<AiReport> createDraft({
    required AiReportType reportType,
    required String title,
    required String periodStartDate,
    required String periodEndDate,
    String generationSource = 'fake',
    AiReportSensitivity sensitivity = AiReportSensitivity.high,
  });

  Future<AiReport> beginGeneration(String reportId);

  Future<AiReport> completeVersion({
    required String reportId,
    required String content,
    required String generationSource,
    String? modelMetadataJson,
    AiReportSensitivity sensitivity = AiReportSensitivity.high,
    AiReportQuality quality = AiReportQuality.unreviewed,
  });

  Future<AiReport> failVersion({
    required String reportId,
    required String errorCode,
    required String generationSource,
  });

  Future<AiReport> archive(String reportId);

  Future<List<AiReportVersion>> listVersions(String reportId);

  Future<AiReport?> findReusableCompleted({
    required AiReportType reportType,
    required String periodStartDate,
    required String periodEndDate,
    required String promptVersion,
    required String inputHash,
    String? generationEndpointHash,
  });

  Future<AiReport> createPending({
    required AiCoachInputBundle input,
    String? generationEndpointHash,
  });

  Future<AiReport> markCompleted({
    required String reportId,
    required String reportContent,
    String? structuredOutputJson,
    String? provider,
    String? model,
  });

  Future<AiReport> markFailed({
    required String reportId,
    required String errorCode,
  });

  Future<AiReport?> getById(String id);

  Future<List<AiReport>> listRecent({int limit = 20});

  Future<List<AiReport>> listAll();

  Future<List<AiReport>> listPending();

  Future<void> softDelete(String id);
}
