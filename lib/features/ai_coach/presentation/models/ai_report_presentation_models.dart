import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_version.dart';

final class AiReportListItemModel {
  const AiReportListItemModel({
    required this.id,
    required this.reportType,
    required this.reportTypeLabel,
    required this.title,
    required this.periodStartDate,
    required this.periodEndDate,
    required this.status,
    required this.statusLabel,
    required this.createdAtLabel,
    required this.updatedAtLabel,
    required this.currentVersion,
    required this.syncStatus,
  });

  final String id;
  final AiReportType reportType;
  final String reportTypeLabel;
  final String title;
  final String periodStartDate;
  final String periodEndDate;
  final AiReportStatus status;
  final String statusLabel;
  final String createdAtLabel;
  final String updatedAtLabel;
  final int currentVersion;
  final String syncStatus;

  bool get isDaily => reportType == AiReportType.dailyInsight;

  String get periodLabel =>
      isDaily ? periodStartDate : '$periodStartDate 至 $periodEndDate';
}

final class AiReportDetailModel {
  const AiReportDetailModel({
    required this.id,
    required this.reportType,
    required this.reportTypeLabel,
    required this.title,
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
    required this.versions,
    required this.currentVersion,
  });

  final String id;
  final AiReportType reportType;
  final String reportTypeLabel;
  final String title;
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
  final List<AiReportVersion> versions;
  final int currentVersion;

  AiReportDetailModel copyWith({AiReportStatus? status, String? statusLabel}) {
    return AiReportDetailModel(
      id: id,
      reportType: reportType,
      reportTypeLabel: reportTypeLabel,
      title: title,
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
      versions: versions,
      currentVersion: currentVersion,
    );
  }

  bool get isDaily => reportType == AiReportType.dailyInsight;

  String get periodLabel =>
      isDaily ? periodStartDate : '$periodStartDate 至 $periodEndDate';
}
