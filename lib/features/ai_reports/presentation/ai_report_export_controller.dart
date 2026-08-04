import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/ai_reports/data/ai_report_export_providers.dart';
import 'package:rebirth/features/ai_reports/domain/ai_report_export.dart';

enum AiReportExportPhase { idle, exporting, saved, cancelled, failed }

enum AiReportExportTarget { singleReport, allReports }

final class AiReportExportViewState {
  const AiReportExportViewState({
    this.phase = AiReportExportPhase.idle,
    this.target,
    this.reportId,
    this.reportCount = 0,
    this.message,
  });

  final AiReportExportPhase phase;
  final AiReportExportTarget? target;
  final String? reportId;
  final int reportCount;
  final String? message;

  bool get isExporting => phase == AiReportExportPhase.exporting;
}

final aiReportExportControllerProvider =
    NotifierProvider.autoDispose<
      AiReportExportController,
      AiReportExportViewState
    >(AiReportExportController.new);

class AiReportExportController extends Notifier<AiReportExportViewState> {
  @override
  AiReportExportViewState build() => const AiReportExportViewState();

  Future<AiReportExportViewState> exportReport(String reportId) => _export(
    target: AiReportExportTarget.singleReport,
    reportId: reportId,
    operation: () =>
        ref.read(aiReportExportServiceProvider).exportReport(reportId),
  );

  Future<AiReportExportViewState> exportAllReports() => _export(
    target: AiReportExportTarget.allReports,
    operation: () => ref.read(aiReportExportServiceProvider).exportAllReports(),
  );

  Future<AiReportExportViewState> _export({
    required AiReportExportTarget target,
    String? reportId,
    required Future<AiReportExportResult> Function() operation,
  }) async {
    if (state.isExporting) return state;
    state = AiReportExportViewState(
      phase: AiReportExportPhase.exporting,
      target: target,
      reportId: reportId,
    );
    try {
      final result = await operation();
      if (!ref.mounted) return state;
      state = AiReportExportViewState(
        phase: result.disposition == AiReportExportDisposition.saved
            ? AiReportExportPhase.saved
            : AiReportExportPhase.cancelled,
        target: target,
        reportId: reportId,
        reportCount: result.reportCount,
      );
    } on AiReportExportException catch (error) {
      if (!ref.mounted) return state;
      state = AiReportExportViewState(
        phase: AiReportExportPhase.failed,
        target: target,
        reportId: reportId,
        message: _messageFor(error.failure),
      );
    } catch (_) {
      if (!ref.mounted) return state;
      state = AiReportExportViewState(
        phase: AiReportExportPhase.failed,
        target: target,
        reportId: reportId,
        message: '导出失败，报告内容和状态均未改变，请重试。',
      );
    }
    return state;
  }

  String _messageFor(AiReportExportFailure failure) => switch (failure) {
    AiReportExportFailure.accessDenied => '当前登录账号已变化，未导出任何报告。',
    AiReportExportFailure.reportNotFound => '找不到要导出的报告，它可能已被删除。',
    AiReportExportFailure.invalidData => '报告导出数据无效，未写入文件。',
  };
}
