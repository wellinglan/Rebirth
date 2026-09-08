import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/sync/data/default_sync_merge_policies.dart';
import 'package:rebirth/features/sync/domain/conflict_reconciliation_service.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_merge_policy.dart';
import 'package:rebirth/features/sync/domain/sync_record_baseline.dart';

void main() {
  final service = const ConflictReconciliationService();
  final policies = createDefaultSyncMergePolicyRegistry();

  group('deterministic reconciliation truth table', () {
    test('exact equality converges without a baseline', () {
      final policy = policies.policyFor(SyncEntityType.profile);
      final payload = _profile('Lin', 'sleep', 'Asia/Shanghai');

      final decision = service.reconcile(
        policy: policy,
        baseline: null,
        local: _live(payload, version: 2),
        remote: _live(payload, version: 9),
      );

      expect(decision.outcome, ConflictReconciliationOutcome.noChange);
      expect(decision.reasonCode, 'exact_equality');
    });

    test('different values without a baseline remain manual', () {
      final policy = policies.policyFor(SyncEntityType.profile);

      final decision = service.reconcile(
        policy: policy,
        baseline: null,
        local: _live(_profile('Local', null, 'UTC'), version: 8),
        remote: _live(_profile('Remote', null, 'UTC'), version: 2),
      );

      expect(decision.outcome, ConflictReconciliationOutcome.manualConflict);
      expect(decision.reasonCode, 'no_trusted_baseline');
    });

    test('local equals base and remote changed adopts remote', () {
      final policy = policies.policyFor(SyncEntityType.profile);
      final base = _profile('Base', null, 'UTC');
      final remote = _profile('Remote', null, 'UTC');

      final decision = service.reconcile(
        policy: policy,
        baseline: _baseline(service, policy, base, version: 3),
        local: _live(base, version: 3),
        remote: _live(remote, version: 4),
      );

      expect(decision.outcome, ConflictReconciliationOutcome.adoptRemote);
    });

    test('remote equals base and local changed retries local', () {
      final policy = policies.policyFor(SyncEntityType.profile);
      final base = _profile('Base', null, 'UTC');
      final local = _profile('Local', null, 'UTC');

      final decision = service.reconcile(
        policy: policy,
        baseline: _baseline(service, policy, base, version: 3),
        local: _live(local, version: 3),
        remote: _live(base, version: 4),
      );

      expect(decision.outcome, ConflictReconciliationOutcome.retryLocal);
    });

    test('non-overlapping groups merge deterministically', () {
      final policy = policies.policyFor(SyncEntityType.profile);
      final base = _profile('Base', 'sleep', 'UTC');
      final local = _profile('Local', 'sleep', 'UTC');
      final remote = _profile('Base', 'research', 'UTC');

      final decision = service.reconcile(
        policy: policy,
        baseline: _baseline(service, policy, base, version: 3),
        local: _live(local, version: 3),
        remote: _live(remote, version: 4),
      );

      expect(decision.outcome, ConflictReconciliationOutcome.mergeAndRetry);
      expect(decision.mergedPayload, {
        'display_name': 'Local',
        'growth_focus': 'research',
        'timezone_id': 'UTC',
      });
    });

    test('different changes in the same group remain manual', () {
      final policy = policies.policyFor(SyncEntityType.profile);
      final base = _profile('Base', null, 'UTC');

      final decision = service.reconcile(
        policy: policy,
        baseline: _baseline(service, policy, base, version: 3),
        local: _live(_profile('Local', null, 'UTC'), version: 3),
        remote: _live(_profile('Remote', null, 'UTC'), version: 4),
      );

      expect(decision.outcome, ConflictReconciliationOutcome.manualConflict);
      expect(decision.reasonCode, 'same_group_changed:display_name');
    });

    test('both sides changing a group to the same value converges', () {
      final policy = policies.policyFor(SyncEntityType.profile);
      final base = _profile('Base', null, 'UTC');
      final same = _profile('Same', null, 'UTC');

      final decision = service.reconcile(
        policy: policy,
        baseline: _baseline(service, policy, base, version: 1),
        local: _live(same, version: 1),
        remote: _live(same, version: 7),
      );

      expect(decision.outcome, ConflictReconciliationOutcome.noChange);
    });

    test('both tombstones converge', () {
      final policy = policies.policyFor(SyncEntityType.plan);

      final decision = service.reconcile(
        policy: policy,
        baseline: null,
        local: _deleted(version: 4),
        remote: _deleted(version: 5),
      );

      expect(decision.outcome, ConflictReconciliationOutcome.noChange);
      expect(decision.reasonCode, 'exact_equality');
    });

    test('local delete retries when remote still equals live base', () {
      final policy = policies.policyFor(SyncEntityType.profile);
      final base = _profile('Base', null, 'UTC');

      final decision = service.reconcile(
        policy: policy,
        baseline: _baseline(service, policy, base, version: 3),
        local: _deleted(version: 3),
        remote: _live(base, version: 4),
      );

      expect(decision.outcome, ConflictReconciliationOutcome.retryLocal);
      expect(decision.reasonCode, 'local_delete_remote_unchanged');
    });

    test('remote delete is adopted when local still equals live base', () {
      final policy = policies.policyFor(SyncEntityType.profile);
      final base = _profile('Base', null, 'UTC');

      final decision = service.reconcile(
        policy: policy,
        baseline: _baseline(service, policy, base, version: 3),
        local: _live(base, version: 3),
        remote: _deleted(version: 4),
      );

      expect(decision.outcome, ConflictReconciliationOutcome.adoptRemote);
      expect(decision.reasonCode, 'remote_delete_local_unchanged');
    });

    test('delete versus update remains manual', () {
      final policy = policies.policyFor(SyncEntityType.profile);
      final base = _profile('Base', null, 'UTC');

      final decision = service.reconcile(
        policy: policy,
        baseline: _baseline(service, policy, base, version: 3),
        local: _deleted(version: 3),
        remote: _live(_profile('Remote', null, 'UTC'), version: 4),
      );

      expect(decision.outcome, ConflictReconciliationOutcome.manualConflict);
      expect(decision.reasonCode, 'delete_vs_remote_update');
    });

    test('an impossible future baseline is rejected', () {
      final policy = policies.policyFor(SyncEntityType.profile);
      final base = _profile('Base', null, 'UTC');

      final decision = service.reconcile(
        policy: policy,
        baseline: _baseline(service, policy, base, version: 9),
        local: _live(_profile('Local', null, 'UTC'), version: 3),
        remote: _live(base, version: 4),
      );

      expect(decision.outcome, ConflictReconciliationOutcome.manualConflict);
      expect(decision.reasonCode, 'baseline_version_invalid');
    });
  });

  group('module merge policies', () {
    test('all synchronized aggregates have one explicit policy', () {
      for (final entityType in SyncEntityType.values) {
        expect(policies.policyFor(entityType).fieldGroups, isNotEmpty);
      }
    });

    test('Today keeps null and zero as different values', () {
      final policy = policies.policyFor(SyncEntityType.today);
      final base = <String, Object?>{'research_minutes': null};
      final local = <String, Object?>{'research_minutes': 0};

      final decision = service.reconcile(
        policy: policy,
        baseline: _baseline(service, policy, base, version: 2),
        local: _live(local, version: 2),
        remote: _live(base, version: 3),
      );

      expect(decision.outcome, ConflictReconciliationOutcome.retryLocal);
      expect(
        service.hashGroups(policy, base)['research'],
        isNot(service.hashGroups(policy, local)['research']),
      );
    });

    test('Today and Health retain 1-10 scores as exact values', () {
      final today = policies.policyFor(SyncEntityType.today);
      final health = policies.policyFor(SyncEntityType.health);

      expect(
        service.hashGroups(today, {'mood_score': 1})['mood_score'],
        isNot(service.hashGroups(today, {'mood_score': 10})['mood_score']),
      );
      expect(
        service.hashGroups(health, {
          'physical_state_score': 1,
        })['physical_state'],
        isNot(
          service.hashGroups(health, {
            'physical_state_score': 10,
          })['physical_state'],
        ),
      );
    });

    test('Journal body and answers are one conservative group', () {
      final groups = policies
          .policyFor(SyncEntityType.journal)
          .fieldGroups
          .associateById();

      expect(
        groups['content']!.keys,
        containsAll(['prompt_items', 'most_important_accomplishment']),
      );
    });

    test('prompt configuration and AI report aggregate stay atomic', () {
      expect(
        policies
            .policyFor(SyncEntityType.journalPromptConfiguration)
            .fieldGroups,
        hasLength(1),
      );
      expect(
        policies.policyFor(SyncEntityType.aiReport).fieldGroups,
        hasLength(1),
      );
    });

    test('AI report archive versus delete remains manual', () {
      final policy = policies.policyFor(SyncEntityType.aiReport);
      final base = <String, Object?>{'report_status': 'completed'};
      final archived = <String, Object?>{'report_status': 'archived'};

      final decision = service.reconcile(
        policy: policy,
        baseline: _baseline(service, policy, base, version: 7),
        local: _live(archived, version: 7),
        remote: _deleted(version: 8),
      );

      expect(decision.outcome, ConflictReconciliationOutcome.manualConflict);
      expect(decision.reasonCode, 'remote_delete_vs_local_update');
    });

    test('AI report archive does not merge with remote version changes', () {
      final policy = policies.policyFor(SyncEntityType.aiReport);
      final base = <String, Object?>{
        'report_status': 'completed',
        'current_version': 1,
        'versions': [
          {'version': 1, 'content': 'base'},
        ],
      };
      final local = <String, Object?>{...base, 'report_status': 'archived'};
      final remote = <String, Object?>{
        ...base,
        'current_version': 2,
        'versions': [
          {'version': 1, 'content': 'base'},
          {'version': 2, 'content': 'remote'},
        ],
      };

      final decision = service.reconcile(
        policy: policy,
        baseline: _baseline(service, policy, base, version: 7),
        local: _live(local, version: 7),
        remote: _live(remote, version: 8),
      );

      expect(decision.outcome, ConflictReconciliationOutcome.manualConflict);
      expect(decision.reasonCode, 'same_group_changed:report_aggregate');
      expect(decision.mergedPayload, isNull);
    });
  });
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

ReconciliationRecordState _live(
  Map<String, Object?> payload, {
  required int version,
}) => ReconciliationRecordState(
  exists: true,
  tombstone: false,
  payload: payload,
  serverVersion: version,
);

ReconciliationRecordState _deleted({required int version}) =>
    ReconciliationRecordState(
      exists: true,
      tombstone: true,
      payload: null,
      serverVersion: version,
    );

SyncRecordBaseline _baseline(
  ConflictReconciliationService service,
  SyncMergePolicy policy,
  Map<String, Object?> payload, {
  required int version,
}) => SyncRecordBaseline(
  localUserId: 'local-user',
  entityType: policy.entityType.wireName,
  recordId: 'record-id',
  baseExists: true,
  baseServerVersion: version,
  baseTombstone: false,
  groupHashes: service.hashGroups(policy, payload),
  capturedAt: 1,
);

extension on Iterable<SyncFieldGroup> {
  Map<String, SyncFieldGroup> associateById() => {
    for (final group in this) group.id: group,
  };
}
