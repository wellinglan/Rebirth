import 'ai_report.dart';
import 'ai_report_type.dart';

final class AiReportGenerationRequest {
  const AiReportGenerationRequest({
    required this.reportType,
    required this.title,
    required this.periodStartDate,
    required this.periodEndDate,
  });

  final AiReportType reportType;
  final String title;
  final String periodStartDate;
  final String periodEndDate;
}

abstract interface class AiReportGenerationService {
  Future<AiReport> generate(AiReportGenerationRequest request);
}
