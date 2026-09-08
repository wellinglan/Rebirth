import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/sync/application/sync_conflict_reconciliation_runner.dart';
import 'package:rebirth/features/sync/data/default_sync_merge_policies.dart';
import 'package:rebirth/features/sync/domain/conflict_reconciliation_service.dart';
import 'package:rebirth/features/sync/domain/sync_conflict.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_adapter.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/domain/sync_record_baseline.dart';
import 'package:rebirth/features/sync/domain/sync_record_baseline_repository.dart';

void main() {
  const scope = SyncConflictScope(
    localUserId: 'local-user',
    endpointKey: 'https://sync.example.test',
    cloudUserId: 'cloud-user',
  );
  final policies = createDefaultSyncMergePolicyRegistry();
  const reconciliation = ConflictReconciliationService();

  test('remote-only change is adopted and counted automatically', () async {
    final base = _profile('Base', null, 'UTC');
    final conflict = _conflict(
      local: base,
      remote: _profile('Remote', null, 'UTC'),
    );
    final repository = _FakeConflictRepository([conflict]);
    final runner = _runner(
      scopeLoader: () async => scope,
      conflicts: repository,
      baselines: _FakeBaselines({
        conflict.id: _baseline(reconciliation, policies, conflict, base),
      }),
      policies: policies,
      snapshot: (_) async => conflict.localSnapshot,
      sync:
          ({
            required direction,
            required entityTypes,
            required pullMode,
          }) async {
            expect(direction, SyncRunDirection.pull);
            expect(pullMode, SyncPullMode.preferRemoteConflictResolution);
            repository.resolve(conflict.id);
            return _runResult(conflict.entityType, pulled: 1);
          },
    );

    final result = await runner.reconcile(
      entityTypes: const [SyncEntityType.profile],
      initialResult: _initial(SyncEntityType.profile),
    );

    expect(repository.adoptRequests, [conflict.id]);
    expect(result.automaticallyReconciledCount, 1);
    expect(result.resultFor(SyncEntityType.profile)?.conflictCount, 0);
  });

  test('local-only change retries against latest remote version', () async {
    final base = _profile('Base', null, 'UTC');
    final conflict = _conflict(
      local: _profile('Local', null, 'UTC'),
      remote: base,
    );
    final repository = _FakeConflictRepository([conflict]);
    var prepareCalls = 0;
    final runner = _runner(
      scopeLoader: () async => scope,
      conflicts: repository,
      baselines: _FakeBaselines({
        conflict.id: _baseline(reconciliation, policies, conflict, base),
      }),
      policies: policies,
      snapshot: (_) async => conflict.localSnapshot,
      prepare:
          ({
            required scope,
            required conflictId,
            required expectedLocal,
            mergedPayload,
          }) async {
            prepareCalls += 1;
            expect(mergedPayload, isNull);
          },
      sync:
          ({
            required direction,
            required entityTypes,
            required pullMode,
          }) async {
            expect(direction, SyncRunDirection.push);
            repository.resolve(conflict.id);
            return _runResult(conflict.entityType, pushed: 1);
          },
    );

    final result = await runner.reconcile(
      entityTypes: const [SyncEntityType.profile],
      initialResult: _initial(SyncEntityType.profile),
    );

    expect(prepareCalls, 1);
    expect(result.automaticallyReconciledCount, 1);
  });

  test('non-overlapping changes pass a merged payload to one retry', () async {
    final base = _profile('Base', 'sleep', 'UTC');
    final conflict = _conflict(
      local: _profile('Local', 'sleep', 'UTC'),
      remote: _profile('Base', 'research', 'UTC'),
    );
    final repository = _FakeConflictRepository([conflict]);
    Map<String, Object?>? merged;
    final runner = _runner(
      scopeLoader: () async => scope,
      conflicts: repository,
      baselines: _FakeBaselines({
        conflict.id: _baseline(reconciliation, policies, conflict, base),
      }),
      policies: policies,
      snapshot: (_) async => conflict.localSnapshot,
      prepare:
          ({
            required scope,
            required conflictId,
            required expectedLocal,
            mergedPayload,
          }) async {
            merged = (mergedPayload as _MapPayload).value;
          },
      sync:
          ({
            required direction,
            required entityTypes,
            required pullMode,
          }) async {
            repository.resolve(conflict.id);
            return _runResult(conflict.entityType, pushed: 1);
          },
    );

    final result = await runner.reconcile(
      entityTypes: const [SyncEntityType.profile],
      initialResult: _initial(SyncEntityType.profile),
    );

    expect(merged, _profile('Local', 'research', 'UTC'));
    expect(result.automaticallyReconciledCount, 1);
  });

  test('same-group ambiguity stays in the manual conflict center', () async {
    final base = _profile('Base', null, 'UTC');
    final conflict = _conflict(
      local: _profile('Local', null, 'UTC'),
      remote: _profile('Remote', null, 'UTC'),
    );
    final repository = _FakeConflictRepository([conflict]);
    var syncCalls = 0;
    final runner = _runner(
      scopeLoader: () async => scope,
      conflicts: repository,
      baselines: _FakeBaselines({
        conflict.id: _baseline(reconciliation, policies, conflict, base),
      }),
      policies: policies,
      snapshot: (_) async => conflict.localSnapshot,
      sync:
          ({
            required direction,
            required entityTypes,
            required pullMode,
          }) async {
            syncCalls += 1;
            return _runResult(conflict.entityType);
          },
    );

    final result = await runner.reconcile(
      entityTypes: const [SyncEntityType.profile],
      initialResult: _initial(SyncEntityType.profile),
    );

    expect(syncCalls, 0);
    expect(result.automaticallyReconciledCount, 0);
    expect(result.resultFor(SyncEntityType.profile)?.conflictCount, 1);
    expect(repository.active, hasLength(1));
  });

  test('a repeated OCC is recalculated once and never loops', () async {
    final base = _profile('Base', null, 'UTC');
    final conflict = _conflict(
      local: _profile('Local', null, 'UTC'),
      remote: base,
    );
    final repository = _FakeConflictRepository([conflict]);
    var syncCalls = 0;
    var prepareCalls = 0;
    final runner = _runner(
      scopeLoader: () async => scope,
      conflicts: repository,
      baselines: _FakeBaselines({
        conflict.id: _baseline(reconciliation, policies, conflict, base),
      }),
      policies: policies,
      snapshot: (_) async => conflict.localSnapshot,
      prepare:
          ({
            required scope,
            required conflictId,
            required expectedLocal,
            mergedPayload,
          }) async {
            prepareCalls += 1;
          },
      sync:
          ({
            required direction,
            required entityTypes,
            required pullMode,
          }) async {
            syncCalls += 1;
            return direction == SyncRunDirection.push
                ? _runResult(
                    conflict.entityType,
                    conflict: 1,
                    failure: const SyncFailure(
                      reason: SyncFailureReason.conflict,
                      phase: SyncRunPhase.push,
                      message: 'OCC',
                    ),
                  )
                : _runResult(conflict.entityType);
          },
    );

    final result = await runner.reconcile(
      entityTypes: const [SyncEntityType.profile],
      initialResult: _initial(SyncEntityType.profile),
    );

    expect(prepareCalls, 2);
    expect(syncCalls, 3);
    expect(result.automaticallyReconciledCount, 0);
    expect(result.resultFor(SyncEntityType.profile)?.conflictCount, 1);
  });

  test(
    'a local change after the decision falls back to manual conflict',
    () async {
      final base = _profile('Base', null, 'UTC');
      final conflict = _conflict(
        local: _profile('Local', null, 'UTC'),
        remote: base,
      );
      final repository = _FakeConflictRepository([conflict]);
      var syncCalls = 0;
      final runner = _runner(
        scopeLoader: () async => scope,
        conflicts: repository,
        baselines: _FakeBaselines({
          conflict.id: _baseline(reconciliation, policies, conflict, base),
        }),
        policies: policies,
        snapshot: (_) async => conflict.localSnapshot,
        prepare:
            ({
              required scope,
              required conflictId,
              required expectedLocal,
              mergedPayload,
            }) async {
              throw const SyncConflictChangedException();
            },
        sync:
            ({
              required direction,
              required entityTypes,
              required pullMode,
            }) async {
              syncCalls += 1;
              return _runResult(conflict.entityType);
            },
      );

      final result = await runner.reconcile(
        entityTypes: const [SyncEntityType.profile],
        initialResult: _initial(SyncEntityType.profile),
      );

      expect(syncCalls, 0);
      expect(result.automaticallyReconciledCount, 0);
      expect(result.resultFor(SyncEntityType.profile)?.conflictCount, 1);
      expect(repository.active, hasLength(1));
    },
  );

  test('an account or endpoint switch invalidates the old result', () async {
    final conflict = _conflict(
      local: _profile('Base', null, 'UTC'),
      remote: _profile('Remote', null, 'UTC'),
    );
    final repository = _FakeConflictRepository([conflict]);
    var scopeReads = 0;
    var syncCalls = 0;
    final initial = _initial(SyncEntityType.profile);
    final runner = _runner(
      scopeLoader: () async {
        scopeReads += 1;
        return scopeReads == 1
            ? scope
            : const SyncConflictScope(
                localUserId: 'account-b',
                endpointKey: 'https://other.example.test',
                cloudUserId: 'cloud-b',
              );
      },
      conflicts: repository,
      baselines: _FakeBaselines(const {}),
      policies: policies,
      snapshot: (_) async => conflict.localSnapshot,
      sync:
          ({
            required direction,
            required entityTypes,
            required pullMode,
          }) async {
            syncCalls += 1;
            return _runResult(conflict.entityType);
          },
    );

    final result = await runner.reconcile(
      entityTypes: const [SyncEntityType.profile],
      initialResult: initial,
    );

    expect(identical(result, initial), isTrue);
    expect(syncCalls, 0);
    expect(repository.active, hasLength(1));
  });

  test(
    'lost session or device readiness prevents reconciliation writes',
    () async {
      final base = _profile('Base', null, 'UTC');
      final conflict = _conflict(
        local: _profile('Local', null, 'UTC'),
        remote: base,
      );
      final repository = _FakeConflictRepository([conflict]);
      var prepareCalls = 0;
      var syncCalls = 0;
      final runner = _runner(
        scopeLoader: () async => scope,
        executionGuard: (_) async => false,
        conflicts: repository,
        baselines: _FakeBaselines({
          conflict.id: _baseline(reconciliation, policies, conflict, base),
        }),
        policies: policies,
        snapshot: (_) async => conflict.localSnapshot,
        prepare:
            ({
              required scope,
              required conflictId,
              required expectedLocal,
              mergedPayload,
            }) async {
              prepareCalls += 1;
            },
        sync:
            ({
              required direction,
              required entityTypes,
              required pullMode,
            }) async {
              syncCalls += 1;
              return _runResult(conflict.entityType);
            },
      );

      final initial = _initial(SyncEntityType.profile);
      final result = await runner.reconcile(
        entityTypes: const [SyncEntityType.profile],
        initialResult: initial,
      );

      expect(identical(result, initial), isTrue);
      expect(prepareCalls, 0);
      expect(syncCalls, 0);
      expect(repository.active, hasLength(1));
    },
  );
}

SyncConflictReconciliationRunner _runner({
  required ReconciliationScopeLoader scopeLoader,
  required _FakeConflictRepository conflicts,
  required SyncRecordBaselineRepository baselines,
  required SyncMergePolicyRegistry policies,
  required Future<SyncConflictSnapshot?> Function(String recordId) snapshot,
  required ReconciliationSyncRunner sync,
  ReconciliationRetryPreparer? prepare,
  ReconciliationExecutionGuard? executionGuard,
}) {
  final adapters = SyncEntityAdapterRegistry([
    for (final type in SyncEntityType.values) _MapAdapter(type),
  ]);
  return SyncConflictReconciliationRunner(
    syncRunner: sync,
    conflicts: conflicts,
    baselines: baselines,
    policies: policies,
    adapters: adapters,
    prepareLocalRetry:
        prepare ??
        ({
          required scope,
          required conflictId,
          required expectedLocal,
          mergedPayload,
        }) async {},
    scopeLoader: scopeLoader,
    executionGuard: executionGuard ?? (_) async => true,
    snapshotLoader:
        ({required entityType, required localUserId, required recordId}) =>
            snapshot(recordId),
  );
}

Map<String, Object?> _profile(
  String displayName,
  String? growthFocus,
  String timezone,
) => {
  'display_name': displayName,
  'growth_focus': growthFocus,
  'timezone_id': timezone,
};

SyncConflictRecord _conflict({
  required Map<String, Object?> local,
  required Map<String, Object?> remote,
}) => SyncConflictRecord(
  id: 'conflict-profile',
  scope: const SyncConflictScope(
    localUserId: 'local-user',
    endpointKey: 'https://sync.example.test',
    cloudUserId: 'cloud-user',
  ),
  entityType: SyncEntityType.profile,
  recordId: 'profile-record',
  remoteRecordId: 'profile-record',
  localSnapshot: SyncConflictSnapshot(
    payload: _MapPayload(local),
    updatedAt: 900,
    deletedAt: null,
    serverVersion: 2,
    originDeviceId: 'local-device',
  ),
  remoteSnapshot: SyncConflictSnapshot(
    payload: _MapPayload(remote),
    updatedAt: 100,
    deletedAt: null,
    serverVersion: 3,
    originDeviceId: 'remote-device',
  ),
  remoteOperation: SyncConflictOperation.upsert,
  detectedAt: 1,
  lastSeenAt: 1,
  resolutionStatus: SyncConflictResolutionStatus.unresolved,
  resolvedAt: null,
);

SyncRecordBaseline _baseline(
  ConflictReconciliationService service,
  SyncMergePolicyRegistry policies,
  SyncConflictRecord conflict,
  Map<String, Object?> payload,
) => SyncRecordBaseline(
  localUserId: conflict.scope.localUserId,
  entityType: conflict.entityType.wireName,
  recordId: conflict.recordId,
  baseExists: true,
  baseServerVersion: 2,
  baseTombstone: false,
  groupHashes: service.hashGroups(
    policies.policyFor(conflict.entityType),
    payload,
  ),
  capturedAt: 1,
);

SyncRunResult _initial(SyncEntityType type) => _runResult(type, conflict: 1);

SyncRunResult _runResult(
  SyncEntityType type, {
  int pushed = 0,
  int pulled = 0,
  int conflict = 0,
  SyncFailure? failure,
}) => SyncRunResult(
  direction: SyncRunDirection.twoWay,
  phases: const [SyncRunPhase.completed],
  entityResults: [
    SyncEntityResult(
      entityType: type,
      status: conflict > 0
          ? SyncEntityStatus.conflict
          : pushed > 0 || pulled > 0
          ? SyncEntityStatus.succeeded
          : SyncEntityStatus.noChanges,
      message: 'result',
      pushedCount: pushed,
      pulledCount: pulled,
      conflictCount: conflict,
    ),
  ],
  startedAt: 1,
  completedAt: 2,
  failure: failure,
);

final class _MapPayload implements SyncEntityPayload {
  const _MapPayload(this.value);

  final Map<String, Object?> value;
}

final class _MapAdapter implements SyncEntityAdapter {
  const _MapAdapter(this.entityType);

  @override
  final SyncEntityType entityType;

  @override
  Map<String, Object?> encodePayload(SyncEntityPayload payload) =>
      (payload as _MapPayload).value;

  @override
  SyncChange decodeRemoteChange({
    required String recordId,
    required Map<String, Object?> payload,
    required int updatedAt,
    required int? deletedAt,
    required String originDeviceId,
    required int serverVersion,
  }) => SyncChange(
    entityType: entityType,
    operation: deletedAt == null ? SyncOperation.upsert : SyncOperation.delete,
    recordId: recordId,
    payload: deletedAt == null ? _MapPayload(payload) : null,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
    originDeviceId: originDeviceId,
    serverVersion: serverVersion,
  );

  @override
  Future<List<SyncPushItem>> collectPending() async => const [];

  @override
  Future<SyncEntityResult> acknowledgePush({
    required List<SyncPushItem> submitted,
    required List<SyncAcknowledgement> accepted,
    required List<SyncConflict> conflicts,
    required int syncedAt,
  }) async => throw UnimplementedError();

  @override
  Future<SyncEntityResult> applyRemoteChanges({
    required List<SyncChange> changes,
    required int syncedAt,
    SyncPullMode pullMode = SyncPullMode.incremental,
  }) async => throw UnimplementedError();
}

final class _FakeBaselines implements SyncRecordBaselineRepository {
  _FakeBaselines(this.values);

  final Map<String, SyncRecordBaseline> values;

  @override
  Future<SyncRecordBaseline?> read({
    required String localUserId,
    required String entityType,
    required String recordId,
  }) async {
    final value = values.values
        .where(
          (candidate) =>
              candidate.localUserId == localUserId &&
              candidate.entityType == entityType &&
              candidate.recordId == recordId,
        )
        .firstOrNull;
    return value;
  }

  @override
  Future<void> write(SyncRecordBaseline baseline) async {
    values[baseline.recordId] = baseline;
  }

  @override
  Future<void> delete({
    required String localUserId,
    required String entityType,
    required String recordId,
  }) async {
    values.remove(recordId);
  }
}

final class _FakeConflictRepository implements SyncConflictRepository {
  _FakeConflictRepository(Iterable<SyncConflictRecord> conflicts)
    : _values = {for (final conflict in conflicts) conflict.id: conflict};

  final Map<String, SyncConflictRecord> _values;
  final List<String> adoptRequests = [];

  List<SyncConflictRecord> get active =>
      _values.values.where((conflict) => conflict.isActive).toList();

  void resolve(String id) {
    final current = _values[id]!;
    _values[id] = _copy(
      current,
      status: SyncConflictResolutionStatus.resolvedAdoptRemote,
      resolvedAt: 5,
    );
  }

  @override
  Future<SyncConflictRecord> getConflict(
    SyncConflictScope scope,
    String id,
  ) async => _values[id]!;

  @override
  Future<List<SyncConflictRecord>> listActiveConflicts(
    SyncConflictScope scope,
  ) async => active;

  @override
  Future<void> markAdoptRemoteRequested(
    SyncConflictScope scope,
    String id,
  ) async {
    adoptRequests.add(id);
    final current = _values[id]!;
    _values[id] = _copy(
      current,
      status: SyncConflictResolutionStatus.adoptRemoteRequested,
    );
  }

  @override
  Future<void> markKeepLocalRequested(
    SyncConflictScope scope,
    String id,
  ) async {}

  @override
  Stream<int> watchActiveConflictCount(SyncConflictScope scope) =>
      Stream.value(active.length);

  @override
  Future<SyncConflictRecord?> findActiveConflict({
    required SyncConflictScope scope,
    required SyncEntityType entityType,
    required String recordId,
  }) async => null;

  @override
  Future<SyncConflictRecord?> findActiveConflictByRemoteRecordId({
    required SyncConflictScope scope,
    required SyncEntityType entityType,
    required String remoteRecordId,
  }) async => null;

  @override
  Future<SyncConflictRecord> hydrateRemoteSnapshot({
    required SyncConflictScope scope,
    required SyncEntityType entityType,
    required String recordId,
    String? remoteRecordId,
    required SyncConflictOperation operation,
    required SyncConflictSnapshot remoteSnapshot,
    required int seenAt,
  }) async => throw UnimplementedError();

  @override
  Future<void> markResolvedAdoptRemote(
    SyncConflictScope scope,
    String id, {
    required int resolvedAt,
  }) async => resolve(id);

  @override
  Future<void> markResolvedKeepLocal(
    SyncConflictScope scope,
    String id, {
    required int resolvedAt,
  }) async => resolve(id);

  @override
  Future<void> markSuperseded(
    SyncConflictScope scope,
    String id, {
    required int resolvedAt,
  }) async => resolve(id);

  @override
  Future<SyncConflictRecord> upsertDetectedConflict(
    SyncConflictDetection detection,
  ) async => throw UnimplementedError();
}

SyncConflictRecord _copy(
  SyncConflictRecord value, {
  required SyncConflictResolutionStatus status,
  int? resolvedAt,
}) => SyncConflictRecord(
  id: value.id,
  scope: value.scope,
  entityType: value.entityType,
  recordId: value.recordId,
  remoteRecordId: value.remoteRecordId,
  localSnapshot: value.localSnapshot,
  remoteSnapshot: value.remoteSnapshot,
  remoteOperation: value.remoteOperation,
  detectedAt: value.detectedAt,
  lastSeenAt: value.lastSeenAt,
  resolutionStatus: status,
  resolvedAt: resolvedAt,
);

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
