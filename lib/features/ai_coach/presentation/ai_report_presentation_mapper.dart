import 'package:rebirth/features/ai_coach/domain/ai_report.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_version.dart';

import 'ai_coach_formatters.dart';
import 'models/ai_report_presentation_models.dart';

final class AiReportPresentationMapper {
  const AiReportPresentationMapper();

  AiReportListItemModel toListItem(AiReport report) {
    return AiReportListItemModel(
      id: report.id,
      reportType: report.reportType,
      reportTypeLabel: AiCoachFormatters.reportType(report.reportType),
      title: report.title,
      periodStartDate: report.periodStartDate,
      periodEndDate: report.periodEndDate,
      status: report.status,
      statusLabel: AiCoachFormatters.reportStatus(report.status),
      createdAtLabel: AiCoachFormatters.timestamp(report.createdAt),
      updatedAtLabel: AiCoachFormatters.timestamp(report.updatedAt),
      currentVersion: report.currentVersion,
      syncStatus: report.syncStatus,
    );
  }

  AiReportDetailModel toDetail(
    AiReport report, {
    List<AiReportVersion>? versions,
  }) {
    return AiReportDetailModel(
      id: report.id,
      reportType: report.reportType,
      reportTypeLabel: AiCoachFormatters.reportType(report.reportType),
      title: report.title,
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
      reportContent:
          report.status == AiReportStatus.completed ||
              report.status == AiReportStatus.archived
          ? report.reportContent?.trim()
          : null,
      hasStructuredOutput:
          report.structuredOutputJson?.trim().isNotEmpty == true,
      failureMessage: report.status == AiReportStatus.failed
          ? AiCoachFormatters.failureCode(report.errorCode)
          : null,
      hasInputSnapshot: report.hasInputSnapshot,
      versions: versions ?? report.versions,
    );
  }

  String _nullableMetadata(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? '未记录' : trimmed;
  }
}
