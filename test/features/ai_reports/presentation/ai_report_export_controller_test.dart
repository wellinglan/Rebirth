import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_reports/data/ai_report_export_providers.dart';
import 'package:rebirth/features/ai_reports/domain/ai_report_export.dart';
import 'package:rebirth/features/ai_reports/domain/ai_report_export_service.dart';
import 'package:rebirth/features/ai_reports/presentation/ai_report_export_controller.dart';

void main() {
  late _FakeExportService service;
  late ProviderContainer container;
  late ProviderSubscription<AiReportExportViewState> subscription;

  setUp(() {
    service = _FakeExportService();
    container = ProviderContainer(
      overrides: [aiReportExportServiceProvider.overrideWithValue(service)],
    );
    subscription = container.listen(
      aiReportExportControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
  });

  tearDown(() {
    subscription.close();
    container.dispose();
  });

  test('saving state prevents concurrent export operations', () async {
    final completer = Completer<AiReportExportResult>();
    service.allResult = completer.future;
    final controller = container.read(
      aiReportExportControllerProvider.notifier,
    );

    final first = controller.exportAllReports();
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(aiReportExportControllerProvider).isExporting,
      isTrue,
    );

    final duplicate = await controller.exportReport('report-a');
    expect(duplicate.phase, AiReportExportPhase.exporting);
    expect(service.allCalls, 1);
    expect(service.singleCalls, 0);

    completer.complete(
      const AiReportExportResult(
        disposition: AiReportExportDisposition.saved,
        reportCount: 2,
      ),
    );
    final completed = await first;
    expect(completed.phase, AiReportExportPhase.saved);
    expect(completed.reportCount, 2);
  });

  test('cancellation and controlled access failure remain retryable', () async {
    service.singleResults.add(
      () => Future.value(
        const AiReportExportResult(
          disposition: AiReportExportDisposition.cancelled,
          reportCount: 1,
        ),
      ),
    );
    service.singleResults.add(
      () => Future.error(
        const AiReportExportException(AiReportExportFailure.accessDenied),
      ),
    );
    service.singleResults.add(
      () => Future.value(
        const AiReportExportResult(
          disposition: AiReportExportDisposition.saved,
          reportCount: 1,
        ),
      ),
    );
    final controller = container.read(
      aiReportExportControllerProvider.notifier,
    );

    expect(
      (await controller.exportReport('report-a')).phase,
      AiReportExportPhase.cancelled,
    );
    final failed = await controller.exportReport('report-a');
    expect(failed.phase, AiReportExportPhase.failed);
    expect(failed.message, contains('登录账号已变化'));
    expect(failed.message, isNot(contains('Exception')));
    expect(
      (await controller.exportReport('report-a')).phase,
      AiReportExportPhase.saved,
    );
  });

  test('unexpected file failures expose no path or stack details', () async {
    service.allResult = Future.error(
      StateError(r'C:\Users\private\secret-report.json'),
    );

    final state = await container
        .read(aiReportExportControllerProvider.notifier)
        .exportAllReports();

    expect(state.phase, AiReportExportPhase.failed);
    expect(state.message, '导出失败，报告内容和状态均未改变，请重试。');
    expect(state.message, isNot(contains('private')));
  });
}

final class _FakeExportService implements AiReportExportService {
  int singleCalls = 0;
  int allCalls = 0;
  final List<Future<AiReportExportResult> Function()> singleResults = [];
  Future<AiReportExportResult>? allResult;

  @override
  Future<AiReportExportResult> exportReport(String reportId) {
    singleCalls += 1;
    return singleResults.removeAt(0)();
  }

  @override
  Future<AiReportExportResult> exportAllReports() {
    allCalls += 1;
    return allResult ??
        Future.value(
          const AiReportExportResult(
            disposition: AiReportExportDisposition.saved,
            reportCount: 1,
          ),
        );
  }
}
