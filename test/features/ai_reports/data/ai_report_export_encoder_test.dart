import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_scope.dart';
import 'package:rebirth/features/ai_coach/domain/ai_generation_mode.dart';
import 'package:rebirth/features/ai_coach/domain/ai_input_source_ref.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_metadata.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_type.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_version.dart';
import 'package:rebirth/features/ai_reports/data/ai_report_export_encoder.dart';
import 'package:rebirth/features/ai_reports/data/ai_report_export_mapper.dart';
import 'package:rebirth/features/ai_reports/domain/ai_report_export.dart';

void main() {
  const mapper = AiReportExportMapper();
  const encoder = AiReportExportEncoder();

  test('export DTO contains only the stable portable report contract', () {
    final report = _report();
    final dto = mapper.map(report, versions: report.versions);
    final json = jsonEncode(dto.toJson());

    expect(dto.title, '可移植周报');
    expect(dto.type, 'weekly_report');
    expect(dto.lifecycleStatus, 'completed');
    expect(dto.periodStartDate, '2026-07-20');
    expect(dto.periodEndDate, '2026-07-26');
    expect(dto.currentContent, '当前正文');
    expect(dto.versions.map((item) => item.version), [1, 2]);
    expect(dto.versions.map((item) => item.content), ['第一版', '第二版']);

    for (final forbidden in const [
      'report-internal-id',
      'account-private-id',
      'version-internal-id',
      'source-private-id',
      'prompt-secret-version',
      'provider-secret-value',
      'model-secret-value',
      'model-metadata-secret',
      'input-hash-secret',
      'structured-output-private',
      'server_version',
      'sync_status',
      'user_id',
      'device_id',
    ]) {
      expect(json, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('single report Markdown is readable and includes version history', () {
    final dto = mapper.map(_report(), versions: _report().versions);

    final markdown = encoder.encodeMarkdown(
      report: dto,
      exportedAt: '2026-08-05T01:02:03.000Z',
    );

    expect(markdown, startsWith('# 可移植周报'));
    expect(markdown, contains('Rebirth AI Report Markdown 1.0'));
    expect(markdown, contains('2026-07-20 to 2026-07-26'));
    expect(markdown, contains('## Current content'));
    expect(markdown, contains('当前正文'));
    expect(markdown, contains('### Version 1'));
    expect(markdown, contains('第一版'));
    expect(markdown, contains('### Version 2'));
    expect(markdown, contains('第二版'));
    expect(markdown, isNot(contains('provider-secret-value')));
    expect(markdown, isNot(contains('prompt-secret-version')));
  });

  test('library JSON has stable 1.0 envelope and parses normally', () {
    final report = mapper.map(_report(), versions: _report().versions);
    final encoded = encoder.encodeJson(
      AiReportLibraryExport(
        exportedAt: '2026-08-05T01:02:03.000Z',
        reports: [report, report],
      ),
    );
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;

    expect(decoded.keys, ['format_version', 'exported_at', 'reports']);
    expect(decoded['format_version'], '1.0');
    expect(decoded['exported_at'], '2026-08-05T01:02:03.000Z');
    expect(decoded['reports'], hasLength(2));
    expect(
      (decoded['reports'] as List).first,
      containsPair('lifecycle_status', 'completed'),
    );
  });
}

AiReport _report() {
  final versions = [
    _version(number: 2, content: '第二版'),
    _version(number: 1, content: '第一版'),
  ];
  return AiReport(
    id: 'report-internal-id',
    userId: 'account-private-id',
    reportType: AiReportType.weeklyReport,
    periodStartDate: '2026-07-20',
    periodEndDate: '2026-07-26',
    inputSources: [
      AiInputSourceRef(
        table: 'today_records',
        id: 'source-private-id',
        updatedAt: 1,
      ),
    ],
    selectedScopes: const {AiDataScope.todayMetrics},
    inputHash: 'input-hash-secret',
    promptVersion: 'prompt-secret-version',
    provider: 'provider-secret-value',
    model: 'model-secret-value',
    generationMode: AiGenerationMode.manual,
    status: AiReportStatus.completed,
    reportContent: '当前正文',
    structuredOutputJson: '{"value":"structured-output-private"}',
    hasInputSnapshot: true,
    errorCode: null,
    requestedAt: DateTime.utc(2026, 7, 26).millisecondsSinceEpoch,
    generatedAt: DateTime.utc(2026, 7, 26, 0, 1).millisecondsSinceEpoch,
    createdAt: DateTime.utc(2026, 7, 26).millisecondsSinceEpoch,
    updatedAt: DateTime.utc(2026, 7, 26, 0, 1).millisecondsSinceEpoch,
    title: '可移植周报',
    generationSource: 'provider',
    sensitivity: AiReportSensitivity.high,
    quality: AiReportQuality.unreviewed,
    currentVersion: 2,
    syncStatus: 'synced',
    serverVersion: 99,
    lastSyncedAt: 100,
    versions: versions,
  );
}

AiReportVersion _version({required int number, required String content}) {
  return AiReportVersion(
    id: 'version-internal-id-$number',
    reportId: 'report-internal-id',
    version: number,
    status: AiReportStatus.completed,
    generationSource: 'provider',
    modelMetadataJson: '{"value":"model-metadata-secret"}',
    content: content,
    sensitivity: AiReportSensitivity.high,
    quality: AiReportQuality.unreviewed,
    errorCode: null,
    createdAt: DateTime.utc(2026, 7, 26, 0, number).millisecondsSinceEpoch,
    completedAt: DateTime.utc(2026, 7, 26, 0, number).millisecondsSinceEpoch,
  );
}
