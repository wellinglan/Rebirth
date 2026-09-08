import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/features/ai_coach/data/ai_report_feedback_sync_service_impl.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback_remote_data_source.dart';
import 'package:rebirth/features/ai_coach/domain/ai_report_feedback_repository.dart';
import 'package:rebirth/features/sync/domain/conflict_reconciliation_service.dart';
import 'package:rebirth/features/sync/domain/sync_record_baseline.dart';
import 'package:rebirth/features/sync/domain/sync_record_baseline_repository.dart';

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

  test('exact equality auto-converges without a durable baseline', () async {
    final local = _feedback(
      syncStatus: AiReportFeedbackSyncStatus.pendingPush,
      serverVersion: 2,
    );
    final repository = _FakeRepository(pending: [local]);
    final result = await AiReportFeedbackSyncServiceImpl(
      repository: repository,
      remoteDataSource: _FakeRemote(
        mutation: AiReportFeedbackMutationResult(
          outcome: AiReportFeedbackMutationOutcome.conflict,
          remote: _remote(serverVersion: 3),
        ),
        listed: const [],
      ),
    ).synchronize();

    expect(result.automaticallyReconciled, 1);
    expect(result.conflicts, 0);
    expect(repository.syncedVersions, [3]);
  });

  test(
    'remote-only feedback change is adopted from a trusted baseline',
    () async {
      final local = _feedback(
        syncStatus: AiReportFeedbackSyncStatus.pendingPush,
        serverVersion: 2,
      );
      final repository = _FakeRepository(pending: [local]);
      final baselines = _FakeBaselines(
        _baseline(local, helpfulness: AiReportHelpfulness.helpful),
      );
      final result = await AiReportFeedbackSyncServiceImpl(
        repository: repository,
        remoteDataSource: _FakeRemote(
          mutation: AiReportFeedbackMutationResult(
            outcome: AiReportFeedbackMutationOutcome.conflict,
            remote: _remote(
              serverVersion: 3,
              helpfulness: AiReportHelpfulness.notHelpful,
              reasons: const [AiReportFeedbackReason.tooGeneric],
            ),
          ),
          listed: const [],
        ),
        baselines: baselines,
      ).synchronize();

      expect(result.automaticallyReconciled, 1);
      expect(result.pulled, 1);
      expect(result.conflicts, 0);
      expect(repository.current?.helpfulness, AiReportHelpfulness.notHelpful);
    },
  );

  test('local-only feedback change retries once with remote version', () async {
    final local = _feedback(
      helpfulness: AiReportHelpfulness.notHelpful,
      reasons: const [AiReportFeedbackReason.tooGeneric],
      syncStatus: AiReportFeedbackSyncStatus.pendingPush,
      serverVersion: 2,
    );
    final repository = _FakeRepository(pending: [local]);
    final remoteBase = _remote(serverVersion: 3);
    final remote = _FakeRemote(
      mutations: [
        AiReportFeedbackMutationResult(
          outcome: AiReportFeedbackMutationOutcome.conflict,
          remote: remoteBase,
        ),
        AiReportFeedbackMutationResult(
          outcome: AiReportFeedbackMutationOutcome.applied,
          remote: _remote(
            serverVersion: 4,
            helpfulness: AiReportHelpfulness.notHelpful,
            reasons: const [AiReportFeedbackReason.tooGeneric],
          ),
        ),
      ],
      listed: const [],
    );

    final result = await AiReportFeedbackSyncServiceImpl(
      repository: repository,
      remoteDataSource: remote,
      baselines: _FakeBaselines(
        _baseline(local, helpfulness: AiReportHelpfulness.helpful),
      ),
    ).synchronize();

    expect(remote.upsertCalls, 2);
    expect(result.pushed, 1);
    expect(result.automaticallyReconciled, 1);
    expect(result.conflicts, 0);
    expect(repository.syncedVersions, [4]);
  });

  test('a second OCC is bounded and remains a manual conflict', () async {
    final local = _feedback(
      helpfulness: AiReportHelpfulness.notHelpful,
      reasons: const [AiReportFeedbackReason.tooGeneric],
      syncStatus: AiReportFeedbackSyncStatus.pendingPush,
      serverVersion: 2,
    );
    final repository = _FakeRepository(pending: [local]);
    final remote = _FakeRemote(
      mutations: [
        AiReportFeedbackMutationResult(
          outcome: AiReportFeedbackMutationOutcome.conflict,
          remote: _remote(serverVersion: 3),
        ),
        AiReportFeedbackMutationResult(
          outcome: AiReportFeedbackMutationOutcome.conflict,
          remote: _remote(
            serverVersion: 4,
            helpfulness: AiReportHelpfulness.notHelpful,
            reasons: const [AiReportFeedbackReason.repetitive],
          ),
        ),
      ],
      listed: const [],
    );

    final result = await AiReportFeedbackSyncServiceImpl(
      repository: repository,
      remoteDataSource: remote,
      baselines: _FakeBaselines(
        _baseline(local, helpfulness: AiReportHelpfulness.helpful),
      ),
    ).synchronize();

    expect(remote.upsertCalls, 2);
    expect(result.automaticallyReconciled, 0);
    expect(result.conflicts, 1);
  });

  test('a baseline belonging to another account is never used', () async {
    final local = _feedback(
      helpfulness: AiReportHelpfulness.notHelpful,
      reasons: const [AiReportFeedbackReason.tooGeneric],
      syncStatus: AiReportFeedbackSyncStatus.pendingPush,
      serverVersion: 2,
    );
    final repository = _FakeRepository(pending: [local]);
    final foreign = _baseline(
      local,
      helpfulness: AiReportHelpfulness.helpful,
      localUserId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    );
    final remote = _FakeRemote(
      mutation: AiReportFeedbackMutationResult(
        outcome: AiReportFeedbackMutationOutcome.conflict,
        remote: _remote(serverVersion: 3),
      ),
      listed: const [],
    );

    final result = await AiReportFeedbackSyncServiceImpl(
      repository: repository,
      remoteDataSource: remote,
      baselines: _FakeBaselines(foreign),
    ).synchronize();

    expect(remote.upsertCalls, 1);
    expect(result.automaticallyReconciled, 0);
    expect(result.conflicts, 1);
  });
}

AiReportFeedback _feedback({
  AiReportHelpfulness helpfulness = AiReportHelpfulness.helpful,
  Iterable<AiReportFeedbackReason> reasons = const [],
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
  helpfulness: helpfulness,
  reasons: reasons,
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
  _FakeRemote({
    this.mutation,
    this.mutations = const [],
    this.error,
    required this.listed,
  });

  final AiReportFeedbackMutationResult? mutation;
  final List<AiReportFeedbackMutationResult> mutations;
  final ApiException? error;
  final List<AiReportFeedbackRemoteRecord> listed;
  int deleteCalls = 0;
  int upsertCalls = 0;

  AiReportFeedbackMutationResult _result(int call) =>
      mutations.isEmpty ? mutation! : mutations[call - 1];

  @override
  Future<AiReportFeedbackMutationResult> delete(
    AiReportFeedback feedback,
  ) async {
    deleteCalls += 1;
    if (error case final value?) throw value;
    return _result(deleteCalls);
  }

  @override
  Future<List<AiReportFeedbackRemoteRecord>> listAll() async => listed;

  @override
  Future<AiReportFeedbackMutationResult> upsert(
    AiReportFeedback feedback,
  ) async {
    upsertCalls += 1;
    if (error case final value?) throw value;
    return _result(upsertCalls);
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
    final source = current ?? pending.first;
    current = _feedback(
      helpfulness: source.helpfulness,
      reasons: source.reasons,
      syncStatus: AiReportFeedbackSyncStatus.conflict,
      serverVersion: source.serverVersion,
      deletedAt: source.deletedAt,
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
    final source = current ?? pending.first;
    current = _feedback(
      helpfulness: source.helpfulness,
      reasons: source.reasons,
      syncStatus: AiReportFeedbackSyncStatus.synced,
      serverVersion: serverVersion,
      lastSyncedAt: serverUpdatedAt,
      deletedAt: source.deletedAt,
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
  Future<List<AiReportFeedback>> listAllForActiveAccount() async =>
      current == null ? pending : [current!];

  @override
  Future<void> adoptRemote(String id) async {
    final remote = current?.remoteSnapshot;
    if (remote == null) throw StateError('missing remote');
    current = _feedback(
      helpfulness: remote.helpfulness,
      reasons: remote.reasons,
      syncStatus: AiReportFeedbackSyncStatus.synced,
      serverVersion: remote.serverVersion,
      lastSyncedAt: remote.updatedAt,
      deletedAt: remote.deletedAt,
    );
  }

  @override
  Future<void> clear({required String reportId, required int reportVersion}) =>
      throw UnimplementedError();

  @override
  Future<void> keepLocal(String id) async {
    final source = current;
    final remote = source?.remoteSnapshot;
    if (source == null || remote == null) throw StateError('missing conflict');
    current = _feedback(
      helpfulness: source.helpfulness,
      reasons: source.reasons,
      syncStatus: source.deletedAt == null
          ? AiReportFeedbackSyncStatus.pendingPush
          : AiReportFeedbackSyncStatus.pendingDelete,
      serverVersion: remote.serverVersion,
      deletedAt: source.deletedAt,
    );
  }

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

SyncRecordBaseline _baseline(
  AiReportFeedback feedback, {
  required AiReportHelpfulness helpfulness,
  Iterable<AiReportFeedbackReason> reasons = const [],
  String? localUserId,
}) {
  const service = ConflictReconciliationService();
  final codes = reasons.map((reason) => reason.code).toList()..sort();
  return SyncRecordBaseline(
    localUserId: localUserId ?? feedback.userId,
    entityType: SyncRecordBaselineEntity.aiReportFeedback,
    recordId: feedback.id,
    baseExists: true,
    baseServerVersion: feedback.serverVersion ?? 0,
    baseTombstone: false,
    groupHashes: {
      'feedback': service.hashCanonicalValue({
        'helpfulness': helpfulness.databaseValue,
        'reason_codes': codes,
      }),
    },
    capturedAt: 1,
  );
}

final class _FakeBaselines implements SyncRecordBaselineRepository {
  _FakeBaselines(this.value);

  SyncRecordBaseline? value;

  @override
  Future<SyncRecordBaseline?> read({
    required String localUserId,
    required String entityType,
    required String recordId,
  }) async {
    final candidate = value;
    return candidate != null &&
            candidate.localUserId == localUserId &&
            candidate.entityType == entityType &&
            candidate.recordId == recordId
        ? candidate
        : null;
  }

  @override
  Future<void> write(SyncRecordBaseline baseline) async {
    value = baseline;
  }

  @override
  Future<void> delete({
    required String localUserId,
    required String entityType,
    required String recordId,
  }) async {
    value = null;
  }
}
