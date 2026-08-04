import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report.dart';
import 'package:rebirth/features/ai_reports/data/ai_report_export_service_impl.dart';
import 'package:rebirth/features/ai_reports/domain/ai_report_export.dart';
import 'package:rebirth/features/ai_reports/domain/ai_report_file_export_adapter.dart';

import '../../ai_coach/ai_coach_test_support.dart';

void main() {
  late FakeAiReportRepository repository;
  late _RecordingFileAdapter adapter;
  late String? activeUserId;
  late AiReportExportServiceImpl service;

  setUp(() {
    repository = FakeAiReportRepository(
      reports: [buildAiReport(id: 'report-a')],
    );
    adapter = _RecordingFileAdapter();
    activeUserId = 'private-user-id';
    service = AiReportExportServiceImpl(
      repository: repository,
      fileExportAdapter: adapter,
      dateTimeService: DateTimeService(
        now: () => DateTime.utc(2026, 8, 5, 1, 2, 3),
      ),
      activeUserId: () => activeUserId,
    );
  });

  test(
    'single export writes Markdown without mutating repository state',
    () async {
      final before = repository.reports.single;

      final result = await service.exportReport('report-a');

      expect(result.disposition, AiReportExportDisposition.saved);
      expect(result.reportCount, 1);
      expect(adapter.files.single.extension, 'md');
      expect(
        adapter.files.single.fileName,
        'rebirth-ai-report-2026-07-10-to-2026-07-16.md',
      );
      expect(adapter.files.single.content, contains('这是本地保存的报告正文。'));
      expect(repository.reports.single, same(before));
      expect(repository.deleteCalls, 0);
      expect(repository.archiveCalls, 0);
      expect(repository.markCompletedCalls, 0);
      expect(repository.markFailedCalls, 0);
    },
  );

  test('all export writes parseable 1.0 JSON for the active account', () async {
    repository.reports.add(buildAiReport(id: 'report-b'));

    final result = await service.exportAllReports();
    final decoded =
        jsonDecode(adapter.files.single.content) as Map<String, dynamic>;

    expect(result.reportCount, 2);
    expect(adapter.files.single.fileName, 'rebirth-ai-reports-2026-08-05.json');
    expect(decoded['format_version'], '1.0');
    expect(decoded['reports'], hasLength(2));
  });

  test(
    'picker cancellation is explicit and leaves reports unchanged',
    () async {
      adapter.disposition = AiReportFileExportDisposition.cancelled;
      final before = List<AiReport>.of(repository.reports);

      final result = await service.exportReport('report-a');

      expect(result.disposition, AiReportExportDisposition.cancelled);
      expect(repository.reports, orderedEquals(before));
    },
  );

  test('write failure propagates without a database mutation', () async {
    adapter.error = StateError('private file system path');
    final before = repository.reports.single;

    await expectLater(service.exportAllReports(), throwsStateError);

    expect(repository.reports.single, same(before));
    expect(repository.deleteCalls, 0);
    expect(repository.archiveCalls, 0);
  });

  test('signed out and mismatched accounts cannot export', () async {
    activeUserId = null;
    await expectLater(
      service.exportReport('report-a'),
      throwsA(
        isA<AiReportExportException>().having(
          (error) => error.failure,
          'failure',
          AiReportExportFailure.accessDenied,
        ),
      ),
    );
    activeUserId = 'account-b';
    await expectLater(
      service.exportAllReports(),
      throwsA(isA<AiReportExportException>()),
    );
    expect(adapter.files, isEmpty);
  });

  test('account switch before file save aborts the export', () async {
    var reads = 0;
    service = AiReportExportServiceImpl(
      repository: repository,
      fileExportAdapter: adapter,
      dateTimeService: DateTimeService(now: () => DateTime.utc(2026, 8, 5)),
      activeUserId: () => reads++ == 0 ? 'private-user-id' : 'account-b',
    );

    await expectLater(
      service.exportReport('report-a'),
      throwsA(
        isA<AiReportExportException>().having(
          (error) => error.failure,
          'failure',
          AiReportExportFailure.accessDenied,
        ),
      ),
    );
    expect(adapter.files, isEmpty);
  });
}

final class _RecordingFileAdapter implements AiReportFileExportAdapter {
  final List<AiReportExportFile> files = [];
  AiReportFileExportDisposition disposition =
      AiReportFileExportDisposition.saved;
  Object? error;

  @override
  Future<AiReportFileExportDisposition> save(AiReportExportFile file) async {
    if (error case final value?) throw value;
    files.add(file);
    return disposition;
  }
}
