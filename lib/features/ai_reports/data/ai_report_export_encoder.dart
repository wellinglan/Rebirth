import 'dart:convert';

import 'package:rebirth/features/ai_reports/domain/ai_report_export.dart';

final class AiReportExportEncoder {
  const AiReportExportEncoder();

  String encodeMarkdown({
    required AiReportExportRecord report,
    required String exportedAt,
  }) {
    final buffer = StringBuffer()
      ..writeln('# ${_singleLine(report.title)}')
      ..writeln()
      ..writeln('- Export format: Rebirth AI Report Markdown 1.0')
      ..writeln('- Exported at: $exportedAt')
      ..writeln('- Type: ${report.type}')
      ..writeln(
        '- Report period: ${report.periodStartDate} to ${report.periodEndDate}',
      )
      ..writeln('- Lifecycle status: ${report.lifecycleStatus}')
      ..writeln('- Created at: ${report.createdAt}')
      ..writeln('- Completed at: ${report.completedAt ?? '-'}')
      ..writeln()
      ..writeln('## Current content')
      ..writeln()
      ..writeln(_content(report.currentContent))
      ..writeln()
      ..writeln('## Version history')
      ..writeln();

    if (report.versions.isEmpty) {
      buffer.writeln('No saved versions.');
    } else {
      for (final version in report.versions) {
        buffer
          ..writeln('### Version ${version.version}')
          ..writeln()
          ..writeln('- Status: ${version.status}')
          ..writeln('- Created at: ${version.createdAt}')
          ..writeln('- Completed at: ${version.completedAt ?? '-'}')
          ..writeln()
          ..writeln(_content(version.content))
          ..writeln();
      }
    }
    return buffer.toString();
  }

  String encodeJson(AiReportLibraryExport export) =>
      const JsonEncoder.withIndent('  ').convert(export.toJson());

  String _singleLine(String value) =>
      value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

  String _content(String? value) =>
      value == null || value.trim().isEmpty ? 'No report content.' : value;
}
