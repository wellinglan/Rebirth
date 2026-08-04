import 'package:rebirth/features/sync/domain/sync_models.dart';

import 'ai_report_metadata.dart';
import 'ai_report_status.dart';
import 'ai_report_type.dart';

/// The portable, user-owned subset of an AI report.
///
/// Prompt material, input snapshots, provider credentials, model metadata, and
/// generation runtime data intentionally do not belong to this contract.
final class AiReportSyncPayload implements SyncEntityPayload {
  AiReportSyncPayload({
    required this.reportType,
    required this.title,
    required this.periodStartDate,
    required this.periodEndDate,
    required this.status,
    required this.createdAt,
    required this.generationSource,
    required this.sensitivity,
    required this.quality,
    required this.currentVersion,
    required List<AiReportVersionSyncPayload> versions,
  }) : versions = List.unmodifiable(versions);

  final AiReportType reportType;
  final String title;
  final String periodStartDate;
  final String periodEndDate;
  final AiReportStatus status;
  final int createdAt;
  final String generationSource;
  final AiReportSensitivity sensitivity;
  final AiReportQuality quality;
  final int currentVersion;
  final List<AiReportVersionSyncPayload> versions;
}

final class AiReportVersionSyncPayload {
  const AiReportVersionSyncPayload({
    required this.id,
    required this.version,
    required this.status,
    required this.generationSource,
    required this.content,
    required this.sensitivity,
    required this.quality,
    required this.errorCode,
    required this.createdAt,
    required this.completedAt,
  });

  final String id;
  final int version;
  final AiReportStatus status;
  final String generationSource;
  final String? content;
  final AiReportSensitivity sensitivity;
  final AiReportQuality quality;
  final String? errorCode;
  final int createdAt;
  final int? completedAt;
}
