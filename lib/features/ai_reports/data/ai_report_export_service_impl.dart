import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_repository.dart';
import 'package:rebirth/features/ai_reports/domain/ai_report_export.dart';
import 'package:rebirth/features/ai_reports/domain/ai_report_export_service.dart';
import 'package:rebirth/features/ai_reports/domain/ai_report_file_export_adapter.dart';

import 'ai_report_export_encoder.dart';
import 'ai_report_export_mapper.dart';

typedef ActiveAiReportExportUserReader = String? Function();

final class AiReportExportServiceImpl implements AiReportExportService {
  AiReportExportServiceImpl({
    required this.repository,
    required this.fileExportAdapter,
    required this.dateTimeService,
    required this.activeUserId,
    this.mapper = const AiReportExportMapper(),
    this.encoder = const AiReportExportEncoder(),
  });

  final AiReportRepository repository;
  final AiReportFileExportAdapter fileExportAdapter;
  final DateTimeService dateTimeService;
  final ActiveAiReportExportUserReader activeUserId;
  final AiReportExportMapper mapper;
  final AiReportExportEncoder encoder;

  @override
  Future<AiReportExportResult> exportReport(String reportId) async {
    final normalizedId = reportId.trim();
    if (normalizedId.isEmpty) {
      throw const AiReportExportException(AiReportExportFailure.reportNotFound);
    }
    final expectedUserId = _requireActiveUser();
    final report = await repository.getById(normalizedId);
    if (report == null) {
      throw const AiReportExportException(AiReportExportFailure.reportNotFound);
    }
    _requireReportOwner(report, expectedUserId);
    final versions = await repository.listVersions(normalizedId);
    final snapshot = dateTimeService.currentSnapshot();
    final exportedAt = _utcIso(snapshot.utcMilliseconds);
    final record = mapper.map(report, versions: versions);
    _requireSameActiveUser(expectedUserId);
    final disposition = await fileExportAdapter.save(
      AiReportExportFile(
        fileName: _singleReportFileName(report),
        extension: 'md',
        mimeType: 'text/markdown',
        content: encoder.encodeMarkdown(report: record, exportedAt: exportedAt),
      ),
    );
    return AiReportExportResult(
      disposition: _mapDisposition(disposition),
      reportCount: 1,
    );
  }

  @override
  Future<AiReportExportResult> exportAllReports() async {
    final expectedUserId = _requireActiveUser();
    final reports = await repository.listAll();
    final records = <AiReportExportRecord>[];
    for (final report in reports) {
      _requireReportOwner(report, expectedUserId);
      final versions = await repository.listVersions(report.id);
      records.add(mapper.map(report, versions: versions));
    }
    final snapshot = dateTimeService.currentSnapshot();
    final exportedAt = _utcIso(snapshot.utcMilliseconds);
    _requireSameActiveUser(expectedUserId);
    final disposition = await fileExportAdapter.save(
      AiReportExportFile(
        fileName: 'rebirth-ai-reports-${snapshot.localDateString}.json',
        extension: 'json',
        mimeType: 'application/json',
        content: encoder.encodeJson(
          AiReportLibraryExport(exportedAt: exportedAt, reports: records),
        ),
      ),
    );
    return AiReportExportResult(
      disposition: _mapDisposition(disposition),
      reportCount: records.length,
    );
  }

  String _requireActiveUser() {
    final value = activeUserId()?.trim();
    if (value == null || value.isEmpty) {
      throw const AiReportExportException(AiReportExportFailure.accessDenied);
    }
    return value;
  }

  void _requireSameActiveUser(String expectedUserId) {
    if (_requireActiveUser() != expectedUserId) {
      throw const AiReportExportException(AiReportExportFailure.accessDenied);
    }
  }

  void _requireReportOwner(AiReport report, String expectedUserId) {
    if (report.userId != expectedUserId || report.deletedAt != null) {
      throw const AiReportExportException(AiReportExportFailure.accessDenied);
    }
  }

  String _singleReportFileName(AiReport report) {
    final period = report.periodStartDate == report.periodEndDate
        ? report.periodStartDate
        : '${report.periodStartDate}-to-${report.periodEndDate}';
    return 'rebirth-ai-report-$period.md';
  }

  String _utcIso(int milliseconds) => DateTime.fromMillisecondsSinceEpoch(
    milliseconds,
    isUtc: true,
  ).toIso8601String();

  AiReportExportDisposition _mapDisposition(
    AiReportFileExportDisposition disposition,
  ) => switch (disposition) {
    AiReportFileExportDisposition.saved => AiReportExportDisposition.saved,
    AiReportFileExportDisposition.cancelled =>
      AiReportExportDisposition.cancelled,
  };
}
