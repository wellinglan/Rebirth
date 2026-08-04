import 'dart:collection';

final class AiReportExportVersion {
  AiReportExportVersion({
    required this.version,
    required this.status,
    required this.createdAt,
    required this.completedAt,
    required this.content,
  }) {
    if (version <= 0 || status.trim().isEmpty || createdAt.trim().isEmpty) {
      throw ArgumentError('Invalid AI report export version.');
    }
  }

  final int version;
  final String status;
  final String createdAt;
  final String? completedAt;
  final String? content;

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'status': status,
    'created_at': createdAt,
    'completed_at': completedAt,
    'content': content,
  };
}

final class AiReportExportRecord {
  AiReportExportRecord({
    required this.title,
    required this.type,
    required this.periodStartDate,
    required this.periodEndDate,
    required this.lifecycleStatus,
    required this.createdAt,
    required this.completedAt,
    required this.currentContent,
    required List<AiReportExportVersion> versions,
  }) : versions = UnmodifiableListView(versions) {
    if (title.trim().isEmpty ||
        type.trim().isEmpty ||
        periodStartDate.trim().isEmpty ||
        periodEndDate.trim().isEmpty ||
        lifecycleStatus.trim().isEmpty ||
        createdAt.trim().isEmpty) {
      throw ArgumentError('Invalid AI report export record.');
    }
  }

  final String title;
  final String type;
  final String periodStartDate;
  final String periodEndDate;
  final String lifecycleStatus;
  final String createdAt;
  final String? completedAt;
  final String? currentContent;
  final List<AiReportExportVersion> versions;

  Map<String, Object?> toJson() => <String, Object?>{
    'title': title,
    'type': type,
    'period_start_date': periodStartDate,
    'period_end_date': periodEndDate,
    'lifecycle_status': lifecycleStatus,
    'created_at': createdAt,
    'completed_at': completedAt,
    'current_content': currentContent,
    'versions': versions.map((version) => version.toJson()).toList(),
  };
}

final class AiReportLibraryExport {
  AiReportLibraryExport({
    required this.exportedAt,
    required List<AiReportExportRecord> reports,
    this.formatVersion = currentFormatVersion,
  }) : reports = UnmodifiableListView(reports) {
    if (formatVersion != currentFormatVersion || exportedAt.trim().isEmpty) {
      throw ArgumentError('Invalid AI report library export.');
    }
  }

  static const currentFormatVersion = '1.0';

  final String formatVersion;
  final String exportedAt;
  final List<AiReportExportRecord> reports;

  Map<String, Object?> toJson() => <String, Object?>{
    'format_version': formatVersion,
    'exported_at': exportedAt,
    'reports': reports.map((report) => report.toJson()).toList(),
  };
}

final class AiReportExportFile {
  const AiReportExportFile({
    required this.fileName,
    required this.extension,
    required this.mimeType,
    required this.content,
  });

  final String fileName;
  final String extension;
  final String mimeType;
  final String content;
}

enum AiReportFileExportDisposition { saved, cancelled }

enum AiReportExportDisposition { saved, cancelled }

final class AiReportExportResult {
  const AiReportExportResult({
    required this.disposition,
    required this.reportCount,
  });

  final AiReportExportDisposition disposition;
  final int reportCount;
}

enum AiReportExportFailure { accessDenied, reportNotFound, invalidData }

final class AiReportExportException implements Exception {
  const AiReportExportException(this.failure);

  final AiReportExportFailure failure;
}
