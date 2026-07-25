import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/sync/domain/sync_conflict.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/domain/sync_result.dart';
import 'package:rebirth/features/sync/domain/sync_status.dart';

void main() {
  test('sync result keeps accepted records and explicit conflicts', () {
    final result = SyncResult(
      accepted: const [
        SyncedRecord(
          tableName: 'today_records',
          recordId: 'today-1',
          serverVersion: 3,
        ),
      ],
      conflicts: const [
        SyncConflict(
          tableName: 'journal_entries',
          recordId: 'journal-1',
          serverVersion: 4,
          reason: 'stale_client',
        ),
      ],
      serverVersion: 4,
    );

    expect(result.accepted.single.serverVersion, 3);
    expect(result.hasConflicts, isTrue);
    expect(result.conflicts.single.reason, 'stale_client');
  });

  test('disabled sync status is honest about current capability', () {
    const status = SyncStatus.disabled();

    expect(status.phase, SyncPhase.disabled);
    expect(status.isEnabled, isFalse);
    expect(status.deviceRegistered, isFalse);
    expect(status.pendingChangeCount, 0);
  });

  test('entity wire values are explicit and unknown values are rejected', () {
    expect(SyncEntityType.parse('user_profiles'), SyncEntityType.profile);
    expect(SyncEntityType.plan.wireName, 'goals');
    expect(
      () => SyncEntityType.parse('unknown_records'),
      throwsA(isA<SyncUnsupportedEntityException>()),
    );
  });

  test(
    'typed change keeps operation and server version distinct from time',
    () {
      const change = SyncChange(
        entityType: SyncEntityType.profile,
        operation: SyncOperation.delete,
        recordId: 'profile',
        payload: null,
        updatedAt: 100,
        deletedAt: 101,
        originDeviceId: 'installation-1',
        serverVersion: 9,
      );
      const cursor = SyncCursor(
        endpoint: 'https://example.test',
        cloudUserId: 'cloud-user',
        scope: SyncEntityType.profile,
        serverVersion: 8,
      );

      expect(change.operation, SyncOperation.delete);
      expect(change.serverVersion, 9);
      expect(change.updatedAt, 100);
      expect(cursor.serverVersion, 8);
    },
  );

  test('run result reports partial success without hiding failure', () {
    final result = SyncRunResult(
      direction: SyncRunDirection.twoWay,
      phases: const [SyncRunPhase.push, SyncRunPhase.failed],
      entityResults: const [
        SyncEntityResult(
          entityType: SyncEntityType.profile,
          status: SyncEntityStatus.succeeded,
          message: 'ok',
          pushedCount: 1,
        ),
        SyncEntityResult(
          entityType: SyncEntityType.plan,
          status: SyncEntityStatus.failed,
          message: 'failed',
        ),
      ],
      startedAt: 1,
      completedAt: 2,
      failure: const SyncFailure(
        reason: SyncFailureReason.unsupportedEntity,
        phase: SyncRunPhase.failed,
        message: 'failed',
        entityType: SyncEntityType.plan,
      ),
    );

    expect(result.isSuccessful, isFalse);
    expect(result.isPartialSuccess, isTrue);
  });
}
