import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback_remote_data_source.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback_repository.dart';

final class AiReportFeedbackSyncServiceImpl
    implements AiReportFeedbackSyncService {
  const AiReportFeedbackSyncServiceImpl({
    required this.repository,
    required this.remoteDataSource,
  });

  final AiReportFeedbackRepository repository;
  final AiReportFeedbackRemoteDataSource remoteDataSource;

  @override
  Future<AiReportFeedbackSyncSummary> synchronize() async {
    var pushed = 0;
    var pulled = 0;
    var conflicts = 0;
    var deferred = 0;
    for (final local in await repository.listPending()) {
      try {
        final result =
            local.syncStatus == AiReportFeedbackSyncStatus.pendingDelete
            ? await remoteDataSource.delete(local)
            : await remoteDataSource.upsert(local);
        if (result.outcome == AiReportFeedbackMutationOutcome.applied) {
          await repository.markSynced(
            id: local.id,
            serverVersion: result.remote.serverVersion,
            serverUpdatedAt: result.remote.updatedAt,
          );
          pushed += 1;
        } else {
          await repository.markConflict(
            id: local.id,
            remote: result.remote.snapshot,
          );
          conflicts += 1;
        }
      } on ApiException catch (error) {
        if (error.errorCode == 'report_not_synced' ||
            error.errorCode == 'feedback_not_found') {
          deferred += 1;
          continue;
        }
        rethrow;
      }
    }
    for (final remote in await remoteDataSource.listAll()) {
      final before = await repository.getForVersion(
        reportId: remote.reportId,
        reportVersion: remote.reportVersion,
      );
      await repository.applyRemote(remote);
      final after = await repository.getForVersion(
        reportId: remote.reportId,
        reportVersion: remote.reportVersion,
      );
      if (before?.serverVersion != after?.serverVersion) pulled += 1;
      if (after?.syncStatus == AiReportFeedbackSyncStatus.conflict) {
        conflicts += 1;
      }
    }
    return AiReportFeedbackSyncSummary(
      pushed: pushed,
      pulled: pulled,
      conflicts: conflicts,
      deferred: deferred,
    );
  }
}
