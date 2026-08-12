import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/ai_coach/data/ai_report_feedback_sync_service_impl.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback_remote_data_source.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback_repository.dart';

void main() {
  test(
    'pushes pending feedback and then applies newer remote feedback',
    () async {
      final local = _feedback();
      final repository = _FakeRepository(pending: [local]);
      final remote = _FakeRemote(
        mutation: AiReportFeedbackMutationResult(
          outcome: AiReportFeedbackMutationOutcome.applied,
          remote: _remote(serverVersion: 1),
        ),
        listed: [_remote(serverVersion: 2)],
      );

      final result = await AiReportFeedbackSyncServiceImpl(
        repository: repository,
        remoteDataSource: remote,
      ).synchronize();

      expect(result.pushed, 1);
      expect(result.pulled, 1);
      expect(result.conflicts, 0);
      expect(repository.syncedVersions, [1]);
      expect(repository.appliedVersions, [2]);
    },
  );

  test('OCC conflict is retained explicitly and never field-merged', () async {
    final repository = _FakeRepository(pending: [_feedback()]);
    final remoteRecord = _remote(
      serverVersion: 4,
      helpfulness: AiReportHelpfulness.notHelpful,
      reasons: const [AiReportFeedbackReason.tooGeneric],
    );
    final result = await AiReportFeedbackSyncServiceImpl(
      repository: repository,
      remoteDataSource: _FakeRemote(
        mutation: AiReportFeedbackMutationResult(
          outcome: AiReportFeedbackMutationOutcome.conflict,
          remote: remoteRecord,
        ),
        listed: const [],
      ),
    ).synchronize();

    expect(result.pushed, 0);
    expect(result.conflicts, 1);
    expect(
      repository.conflicts.single.helpfulness,
      AiReportHelpfulness.notHelpful,
    );
    expect(repository.syncedVersions, isEmpty);
  });

  test(
    'report-not-synced defers feedback without losing local state',
    () async {
      final repository = _FakeRepository(pending: [_feedback()]);
      final result = await AiReportFeedbackSyncServiceImpl(
        repository: repository,
        remoteDataSource: _FakeRemote(
          error: const ApiException(
            message: 'deferred',
            statusCode: 409,
            errorCode: 'report_not_synced',
          ),
          listed: const [],
        ),
      ).synchronize();

      expect(result.deferred, 1);
      expect(repository.pending, hasLength(1));
      expect(repository.syncedVersions, isEmpty);
    },
  );

  test(
    'pending clear uses the dedicated delete endpoint and converges',
    () async {
      final repository = _FakeRepository(
        pending: [
          _feedback(
            syncStatus: AiReportFeedbackSyncStatus.pendingDelete,
            serverVersion: 2,
            deletedAt: 20,
          ),
        ],
      );
      final remote = _FakeRemote(
        mutation: AiReportFeedbackMutationResult(
          outcome: AiReportFeedbackMutationOutcome.applied,
          remote: _remote(serverVersion: 3, deletedAt: 21),
        ),
        listed: const [],
      );

      final result = await AiReportFeedbackSyncServiceImpl(
        repository: repository,
        remoteDataSource: remote,
      ).synchronize();

      expect(result.pushed, 1);
      expect(remote.deleteCalls, 1);
      expect(remote.upsertCalls, 0);
      expect(repository.syncedVersions, [3]);
    },
  );
}

AiReportFeedback _feedback({
  AiReportFeedbackSyncStatus syncStatus =
      AiReportFeedbackSyncStatus.pendingPush,
  int? serverVersion,
  int? lastSyncedAt,
  int? deletedAt,
  AiReportFeedbackRemoteSnapshot? remoteSnapshot,
}) => AiReportFeedback(
  id: '11111111-1111-4111-8111-111111111111',
  userId: '22222222-2222-4222-8222-222222222222',
  reportId: '33333333-3333-4333-8333-333333333333',
  reportVersion: 1,
  reportType: 'weekly_report',
  helpfulness: AiReportHelpfulness.helpful,
  reasons: const [],
  promptId: 'weekly_report',
  promptVersion: 'weekly-report-v1',
  syncStatus: syncStatus,
  serverVersion: serverVersion,
  lastSyncedAt: lastSyncedAt,
  createdAt: 10,
  updatedAt: 10,
  deletedAt: deletedAt,
  remoteSnapshot: remoteSnapshot,
);

AiReportFeedbackRemoteRecord _remote({
  required int serverVersion,
  AiReportHelpfulness helpfulness = AiReportHelpfulness.helpful,
  Iterable<AiReportFeedbackReason> reasons = const [],
  int? deletedAt,
}) => AiReportFeedbackRemoteRecord(
  id: '11111111-1111-4111-8111-111111111111',
  reportId: '33333333-3333-4333-8333-333333333333',
  reportVersion: 1,
  reportType: 'weekly_report',
  helpfulness: helpfulness,
  reasons: reasons,
  promptId: 'weekly_report',
  promptVersion: 'weekly-report-v1',
  serverVersion: serverVersion,
  createdAt: 10,
  updatedAt: 10 + serverVersion,
  deletedAt: deletedAt,
);

final class _FakeRemote implements AiReportFeedbackRemoteDataSource {
  _FakeRemote({this.mutation, this.error, required this.listed});

  final AiReportFeedbackMutationResult? mutation;
  final ApiException? error;
  final List<AiReportFeedbackRemoteRecord> listed;
  int deleteCalls = 0;
  int upsertCalls = 0;

  @override
  Future<AiReportFeedbackMutationResult> delete(
    AiReportFeedback feedback,
  ) async {
    deleteCalls += 1;
    if (error case final value?) throw value;
    return mutation!;
  }

  @override
  Future<List<AiReportFeedbackRemoteRecord>> listAll() async => listed;

  @override
  Future<AiReportFeedbackMutationResult> upsert(
    AiReportFeedback feedback,
  ) async {
    upsertCalls += 1;
    if (error case final value?) throw value;
    return mutation!;
  }
}

final class _FakeRepository implements AiReportFeedbackRepository {
  _FakeRepository({required this.pending});

  final List<AiReportFeedback> pending;
  final List<int> syncedVersions = [];
  final List<int> appliedVersions = [];
  final List<AiReportFeedbackRemoteSnapshot> conflicts = [];
  AiReportFeedback? current;

  @override
  Future<void> applyRemote(AiReportFeedbackRemoteRecord remote) async {
    appliedVersions.add(remote.serverVersion);
    current = _feedbackFromRemote(remote);
  }

  @override
  Future<void> markConflict({
    required String id,
    required AiReportFeedbackRemoteSnapshot remote,
  }) async {
    conflicts.add(remote);
    current = _feedback(
      syncStatus: AiReportFeedbackSyncStatus.conflict,
      remoteSnapshot: remote,
    );
  }

  @override
  Future<void> markSynced({
    required String id,
    required int serverVersion,
    required int serverUpdatedAt,
  }) async {
    syncedVersions.add(serverVersion);
    current = _feedback(
      syncStatus: AiReportFeedbackSyncStatus.synced,
      serverVersion: serverVersion,
      lastSyncedAt: serverUpdatedAt,
    );
  }

  @override
  Future<AiReportFeedback?> getForVersion({
    required String reportId,
    required int reportVersion,
  }) async => current;

  @override
  Future<List<AiReportFeedback>> listPending() async => pending;

  @override
  Future<List<AiReportFeedback>> listAllForActiveAccount() async => pending;

  @override
  Future<void> adoptRemote(String id) => throw UnimplementedError();

  @override
  Future<void> clear({required String reportId, required int reportVersion}) =>
      throw UnimplementedError();

  @override
  Future<void> keepLocal(String id) => throw UnimplementedError();

  @override
  Future<AiReportFeedback> save({
    required String reportId,
    required int reportVersion,
    required AiReportHelpfulness helpfulness,
    Iterable<AiReportFeedbackReason> reasons = const [],
  }) => throw UnimplementedError();
}

AiReportFeedback _feedbackFromRemote(AiReportFeedbackRemoteRecord remote) =>
    AiReportFeedback(
      id: remote.id,
      userId: '22222222-2222-4222-8222-222222222222',
      reportId: remote.reportId,
      reportVersion: remote.reportVersion,
      reportType: remote.reportType,
      helpfulness: remote.helpfulness,
      reasons: remote.reasons,
      promptId: remote.promptId,
      promptVersion: remote.promptVersion,
      syncStatus: AiReportFeedbackSyncStatus.synced,
      serverVersion: remote.serverVersion,
      lastSyncedAt: remote.updatedAt,
      createdAt: remote.createdAt,
      updatedAt: remote.updatedAt,
      deletedAt: remote.deletedAt,
    );
