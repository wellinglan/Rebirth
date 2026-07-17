import 'ai_coach_input_bundle.dart';
import 'ai_report.dart';
import 'ai_report_type.dart';

abstract interface class AiReportRepository {
  Future<AiReport?> findReusableCompleted({
    required AiReportType reportType,
    required String periodStartDate,
    required String periodEndDate,
    required String promptVersion,
    required String inputHash,
  });

  Future<AiReport> createPending({required AiCoachInputBundle input});

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

  Future<List<AiReport>> listPending();

  Future<void> softDelete(String id);
}
