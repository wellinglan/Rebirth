import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';

final class AiReportListItemModel {
  const AiReportListItemModel({
    required this.id,
    required this.reportType,
    required this.reportTypeLabel,
    required this.periodStartDate,
    required this.periodEndDate,
    required this.status,
    required this.statusLabel,
    required this.requestedAtLabel,
    required this.generatedAtLabel,
    required this.providerModelLabel,
    required this.shortInputHash,
    required this.hasInputSnapshot,
    required this.contentPreview,
  });

  final String id;
  final AiReportType reportType;
  final String reportTypeLabel;
  final String periodStartDate;
  final String periodEndDate;
  final AiReportStatus status;
  final String statusLabel;
  final String requestedAtLabel;
  final String generatedAtLabel;
  final String providerModelLabel;
  final String shortInputHash;
  final bool hasInputSnapshot;
  final String? contentPreview;

  bool get isDaily => reportType == AiReportType.dailyInsight;

  String get periodLabel =>
      isDaily ? periodStartDate : '$periodStartDate 至 $periodEndDate';
}

final class AiReportDetailModel {
  const AiReportDetailModel({
    required this.id,
    required this.reportType,
    required this.reportTypeLabel,
    required this.status,
    required this.statusLabel,
    required this.periodStartDate,
    required this.periodEndDate,
    required this.promptVersion,
    required this.shortInputHash,
    required this.requestedAtLabel,
    required this.generatedAtLabel,
    required this.providerLabel,
    required this.modelLabel,
    required this.reportContent,
    required this.hasStructuredOutput,
    required this.failureMessage,
    required this.hasInputSnapshot,
  });

  final String id;
  final AiReportType reportType;
  final String reportTypeLabel;
  final AiReportStatus status;
  final String statusLabel;
  final String periodStartDate;
  final String periodEndDate;
  final String promptVersion;
  final String shortInputHash;
  final String requestedAtLabel;
  final String generatedAtLabel;
  final String providerLabel;
  final String modelLabel;
  final String? reportContent;
  final bool hasStructuredOutput;
  final String? failureMessage;
  final bool hasInputSnapshot;

  AiReportDetailModel copyWith({AiReportStatus? status, String? statusLabel}) {
    return AiReportDetailModel(
      id: id,
      reportType: reportType,
      reportTypeLabel: reportTypeLabel,
      status: status ?? this.status,
      statusLabel: statusLabel ?? this.statusLabel,
      periodStartDate: periodStartDate,
      periodEndDate: periodEndDate,
      promptVersion: promptVersion,
      shortInputHash: shortInputHash,
      requestedAtLabel: requestedAtLabel,
      generatedAtLabel: generatedAtLabel,
      providerLabel: providerLabel,
      modelLabel: modelLabel,
      reportContent: reportContent,
      hasStructuredOutput: hasStructuredOutput,
      failureMessage: failureMessage,
      hasInputSnapshot: hasInputSnapshot,
    );
  }

  bool get isDaily => reportType == AiReportType.dailyInsight;

  String get periodLabel =>
      isDaily ? periodStartDate : '$periodStartDate 至 $periodEndDate';
}
