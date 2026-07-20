import 'package:rebirth/features/ai_coach/domain/ai_report.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';

import 'ai_coach_formatters.dart';
import 'models/ai_report_presentation_models.dart';

final class AiReportPresentationMapper {
  const AiReportPresentationMapper();

  AiReportListItemModel toListItem(AiReport report) {
    return AiReportListItemModel(
      id: report.id,
      reportType: report.reportType,
      reportTypeLabel: AiCoachFormatters.reportType(report.reportType),
      periodStartDate: report.periodStartDate,
      periodEndDate: report.periodEndDate,
      status: report.status,
      statusLabel: AiCoachFormatters.reportStatus(report.status),
      requestedAtLabel: AiCoachFormatters.timestamp(report.requestedAt),
      generatedAtLabel: AiCoachFormatters.timestamp(report.generatedAt),
      providerModelLabel: _providerModel(report.provider, report.model),
      shortInputHash: AiCoachFormatters.shortHash(report.inputHash),
      hasInputSnapshot: report.hasInputSnapshot,
      contentPreview: report.status == AiReportStatus.completed
          ? _contentPreview(report.reportContent)
          : null,
    );
  }

  AiReportDetailModel toDetail(AiReport report) {
    return AiReportDetailModel(
      id: report.id,
      reportType: report.reportType,
      reportTypeLabel: AiCoachFormatters.reportType(report.reportType),
      status: report.status,
      statusLabel: AiCoachFormatters.reportStatus(report.status),
      periodStartDate: report.periodStartDate,
      periodEndDate: report.periodEndDate,
      promptVersion: report.promptVersion,
      shortInputHash: AiCoachFormatters.shortHash(report.inputHash),
      requestedAtLabel: AiCoachFormatters.timestamp(report.requestedAt),
      generatedAtLabel: AiCoachFormatters.timestamp(report.generatedAt),
      providerLabel: _nullableMetadata(report.provider),
      modelLabel: _nullableMetadata(report.model),
      reportContent: report.status == AiReportStatus.completed
          ? report.reportContent?.trim()
          : null,
      hasStructuredOutput:
          report.structuredOutputJson?.trim().isNotEmpty == true,
      failureMessage: report.status == AiReportStatus.failed
          ? AiCoachFormatters.failureCode(report.errorCode)
          : null,
      hasInputSnapshot: report.hasInputSnapshot,
    );
  }

  String _providerModel(String? provider, String? model) {
    final providerText = provider?.trim();
    final modelText = model?.trim();
    if ((providerText == null || providerText.isEmpty) &&
        (modelText == null || modelText.isEmpty)) {
      return '未记录';
    }
    if (providerText == null || providerText.isEmpty) return modelText!;
    if (modelText == null || modelText.isEmpty) return providerText;
    return '$providerText / $modelText';
  }

  String _nullableMetadata(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? '未记录' : trimmed;
  }

  String? _contentPreview(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text.length <= 120 ? text : '${text.substring(0, 120)}…';
  }
}
