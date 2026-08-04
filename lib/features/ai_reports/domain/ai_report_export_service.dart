import 'ai_report_export.dart';

abstract interface class AiReportExportService {
  Future<AiReportExportResult> exportReport(String reportId);

  Future<AiReportExportResult> exportAllReports();
}
