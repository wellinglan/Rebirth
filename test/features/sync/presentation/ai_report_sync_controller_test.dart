import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback_remote_data_source.dart';
import 'package:rebirth/features/sync/data/sync_conflict_providers.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/presentation/ai_report_sync_controller.dart';
import 'package:rebirth/features/sync/presentation/ai_report_sync_view_state.dart';

void main() {
  test(
    'report success followed by feedback failure is explicit partial success',
    () async {
      final feedback = _FeedbackSync(throwOnSync: true);
      final container = ProviderContainer(
        overrides: [
          syncConflictScopeProvider.overrideWith((ref) async => null),
          aiReportSyncRunnerProvider.overrideWithValue(
            () async => _result(SyncEntityStatus.succeeded),
          ),
          aiReportFeedbackSyncServiceProvider.overrideWithValue(feedback),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(aiReportSyncControllerProvider.notifier)
          .syncAiReports();
      final state = container.read(aiReportSyncControllerProvider);

      expect(result.isPartialSuccess, isTrue);
      expect(
        result.resultFor(SyncEntityType.aiReport)?.status,
        SyncEntityStatus.succeeded,
      );
      expect(state.status, AiReportSyncStatus.partial);
      expect(
        state.feedbackErrorMessage,
        contains('Local feedback was retained'),
      );
      expect(feedback.calls, 1);
    },
  );

  test('failed report sync never submits orphan feedback', () async {
    final feedback = _FeedbackSync();
    final container = ProviderContainer(
      overrides: [
        syncConflictScopeProvider.overrideWith((ref) async => null),
        aiReportSyncRunnerProvider.overrideWithValue(
          () async => _result(SyncEntityStatus.failed),
        ),
        aiReportFeedbackSyncServiceProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(aiReportSyncControllerProvider.notifier)
        .syncAiReports();

    expect(feedback.calls, 0);
    expect(
      container.read(aiReportSyncControllerProvider).status,
      AiReportSyncStatus.failed,
    );
  });

  test('successful feedback convergence exposes module counts', () async {
    final container = ProviderContainer(
      overrides: [
        syncConflictScopeProvider.overrideWith((ref) async => null),
        aiReportSyncRunnerProvider.overrideWithValue(
          () async => _result(SyncEntityStatus.succeeded),
        ),
        aiReportFeedbackSyncServiceProvider.overrideWithValue(
          _FeedbackSync(
            summary: const AiReportFeedbackSyncSummary(
              pushed: 1,
              pulled: 2,
              conflicts: 1,
              deferred: 3,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(aiReportSyncControllerProvider.notifier)
        .syncAiReports();
    final state = container.read(aiReportSyncControllerProvider);
    expect(state.status, AiReportSyncStatus.succeeded);
    expect(state.feedbackPushedCount, 1);
    expect(state.feedbackPulledCount, 2);
    expect(state.feedbackConflictCount, 1);
    expect(state.feedbackDeferredCount, 3);
  });
}

SyncRunResult _result(SyncEntityStatus status) => SyncRunResult(
  direction: SyncRunDirection.twoWay,
  phases: const [SyncRunPhase.completed],
  entityResults: [
    SyncEntityResult(
      entityType: SyncEntityType.aiReport,
      status: status,
      message: 'controlled',
      pushedCount: status == SyncEntityStatus.succeeded ? 1 : 0,
    ),
  ],
  startedAt: 1,
  completedAt: 2,
  failure: status == SyncEntityStatus.failed
      ? const SyncFailure(
          reason: SyncFailureReason.pushFailed,
          phase: SyncRunPhase.push,
          message: 'controlled',
          entityType: SyncEntityType.aiReport,
        )
      : null,
);

final class _FeedbackSync implements AiReportFeedbackSyncService {
  _FeedbackSync({
    this.throwOnSync = false,
    this.summary = const AiReportFeedbackSyncSummary(),
  });

  final bool throwOnSync;
  final AiReportFeedbackSyncSummary summary;
  int calls = 0;

  @override
  Future<AiReportFeedbackSyncSummary> synchronize() async {
    calls += 1;
    if (throwOnSync) throw StateError('offline');
    return summary;
  }
}
