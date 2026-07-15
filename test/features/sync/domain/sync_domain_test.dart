import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/sync/domain/sync_conflict.dart';
import 'package:rebirth/features/sync/domain/sync_item.dart';
import 'package:rebirth/features/sync/domain/sync_result.dart';
import 'package:rebirth/features/sync/domain/sync_status.dart';

void main() {
  test('sync item preserves payload and tombstone metadata', () {
    final item = SyncItem(
      tableName: 'today_records',
      recordId: 'today-1',
      payload: const {'record_date': '2026-07-15'},
      updatedAt: 100,
      deletedAt: 101,
      originDeviceId: 'installation-1',
      clientVersion: 2,
    );

    expect(item.payload['record_date'], '2026-07-15');
    expect(item.isTombstone, isTrue);
    expect(
      () => item.payload['record_date'] = '2026-07-16',
      throwsUnsupportedError,
    );
  });

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
}
