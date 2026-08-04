import 'ai_report_export.dart';

abstract interface class AiReportFileExportAdapter {
  Future<AiReportFileExportDisposition> save(AiReportExportFile file);
}
