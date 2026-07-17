import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_status.dart';
import 'package:rebirth/features/ai_coach/presentation/ai_report_history_controller.dart';

import '../ai_coach_test_support.dart';

void main() {
  late FakeAiReportRepository repository;
  late ProviderContainer container;
  late ProviderSubscription subscription;

  void createContainer() {
    container = ProviderContainer(
      overrides: [aiReportRepositoryProvider.overrideWithValue(repository)],
    );
    subscription = container.listen(
      aiReportHistoryControllerProvider,
      (_, _) {},
    );
  }

  tearDown(() {
    subscription.close();
    container.dispose();
  });

  test('initial load maps all statuses and sorts newest first', () async {
    repository = FakeAiReportRepository(
      reports: [
        buildAiReport(
          id: 'pending',
          status: AiReportStatus.pending,
          requestedAt: 20,
        ),
        buildAiReport(id: 'completed', requestedAt: 30, hasInputSnapshot: true),
        buildAiReport(
          id: 'failed',
          status: AiReportStatus.failed,
          requestedAt: 10,
        ),
      ],
    );
    createContainer();

    final state = await container.read(
      aiReportHistoryControllerProvider.future,
    );

    expect(state.reports.map((report) => report.id), [
      'completed',
      'pending',
      'failed',
    ]);
    expect(state.reports.map((report) => report.statusLabel), [
      '已完成',
      '待处理',
      '生成失败',
    ]);
    expect(state.reports.first.contentPreview, contains('本地保存'));
    expect(state.reports.first.hasInputSnapshot, isTrue);
    expect(repository.listCalls, 1);
  });

  test(
    'empty list loads and reload only queries the local repository',
    () async {
      repository = FakeAiReportRepository();
      createContainer();
      expect(
        (await container.read(
          aiReportHistoryControllerProvider.future,
        )).reports,
        isEmpty,
      );

      repository.reports.add(buildAiReport(id: 'new-local-report'));
      await container.read(aiReportHistoryControllerProvider.notifier).reload();

      expect(
        container
            .read(aiReportHistoryControllerProvider)
            .requireValue
            .reports
            .single
            .id,
        'new-local-report',
      );
      expect(repository.listCalls, 2);
      expect(repository.createPendingCalls, 0);
    },
  );

  test(
    'getById maps detail without exposing snapshot or structured JSON bodies',
    () async {
      repository = FakeAiReportRepository(
        reports: [
          buildAiReport(
            id: 'detail',
            hasInputSnapshot: true,
            provider: null,
            model: null,
          ),
        ],
      );
      createContainer();
      await container.read(aiReportHistoryControllerProvider.future);

      final detail = await container
          .read(aiReportHistoryControllerProvider.notifier)
          .getById('detail');

      expect(detail?.reportContent, '这是本地保存的报告正文。');
      expect(detail?.providerLabel, '未记录');
      expect(detail?.modelLabel, '未记录');
      expect(detail?.hasStructuredOutput, isTrue);
      expect(detail?.hasInputSnapshot, isTrue);
      expect(detail.toString(), isNot(contains('private-user-id')));
      expect(detail.toString(), isNot(contains('not displayed')));
    },
  );

  test(
    'soft delete removes only the selected report and refreshes state',
    () async {
      final untouched = buildAiReport(id: 'untouched');
      repository = FakeAiReportRepository(
        reports: [
          buildAiReport(id: 'delete-me'),
          untouched,
        ],
      );
      createContainer();
      await container.read(aiReportHistoryControllerProvider.future);

      final deleted = await container
          .read(aiReportHistoryControllerProvider.notifier)
          .deleteReport('delete-me');

      expect(deleted, isTrue);
      expect(repository.deleteCalls, 1);
      expect(repository.lastDeletedId, 'delete-me');
      expect(repository.reports, [same(untouched)]);
      expect(
        container
            .read(aiReportHistoryControllerProvider)
            .requireValue
            .reports
            .single
            .id,
        'untouched',
      );
      expect(repository.createPendingCalls, 0);
      expect(repository.markCompletedCalls, 0);
    },
  );

  test('delete failure remains readable and allows retry', () async {
    repository = FakeAiReportRepository(
      reports: [buildAiReport(id: 'retry-delete')],
    )..deleteError = StateError('SQL path private');
    createContainer();
    await container.read(aiReportHistoryControllerProvider.future);
    final controller = container.read(
      aiReportHistoryControllerProvider.notifier,
    );

    expect(await controller.deleteReport('retry-delete'), isFalse);
    var state = container.read(aiReportHistoryControllerProvider).requireValue;
    expect(state.operationError, '本地报告删除失败，请重试。');
    expect(state.operationError, isNot(contains('SQL')));
    expect(state.deletingReportIds, isEmpty);

    repository.deleteError = null;
    expect(await controller.deleteReport('retry-delete'), isTrue);
    state = container.read(aiReportHistoryControllerProvider).requireValue;
    expect(state.reports, isEmpty);
    expect(repository.deleteCalls, 2);
  });

  test('invalid detail id returns null without a repository lookup', () async {
    repository = FakeAiReportRepository();
    createContainer();
    await container.read(aiReportHistoryControllerProvider.future);

    expect(
      await container
          .read(aiReportHistoryControllerProvider.notifier)
          .getById('  '),
      isNull,
    );
    expect(repository.getCalls, 0);
  });
}
