import 'package:rebirth/features/ai_coach/domain/ai_report.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_version.dart';
import 'package:rebirth/features/ai_reports/domain/ai_report_export.dart';

final class AiReportExportMapper {
  const AiReportExportMapper();

  AiReportExportRecord map(
    AiReport report, {
    required List<AiReportVersion> versions,
  }) {
    final orderedVersions = [...versions]
      ..sort((left, right) => left.version.compareTo(right.version));
    return AiReportExportRecord(
      title: report.title,
      type: report.reportType.databaseValue,
      periodStartDate: report.periodStartDate,
      periodEndDate: report.periodEndDate,
      lifecycleStatus: report.status.databaseValue,
      createdAt: _utcIso(report.createdAt),
      completedAt: _nullableUtcIso(report.generatedAt),
      currentContent: report.reportContent,
      versions: orderedVersions
          .map(
            (version) => AiReportExportVersion(
              version: version.version,
              status: version.status.databaseValue,
              createdAt: _utcIso(version.createdAt),
              completedAt: _nullableUtcIso(version.completedAt),
              content: version.content,
            ),
          )
          .toList(growable: false),
    );
  }

  String _utcIso(int milliseconds) => DateTime.fromMillisecondsSinceEpoch(
    milliseconds,
    isUtc: true,
  ).toIso8601String();

  String? _nullableUtcIso(int? milliseconds) =>
      milliseconds == null ? null : _utcIso(milliseconds);
}
