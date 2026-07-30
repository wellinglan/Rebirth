import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/journal/data/journal_conflict_resolution_service_impl.dart';
import 'package:rebirth/features/journal/data/journal_repository_impl.dart';
import 'package:rebirth/features/journal/data/journal_sync_adapter.dart';
import 'package:rebirth/features/journal/data/journal_sync_payload_codec.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_save_data.dart';
import 'package:rebirth/features/journal/domain/journal_sync_payload.dart';
import 'package:rebirth/features/sync/data/sync_conflict_repository_impl.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

void main() {
  late db.AppDatabase database;
  late JournalRepositoryImpl repository;
  late SyncConflictRepositoryImpl conflicts;
  late JournalConflictResolutionServiceImpl service;
  late SyncConflictScope scope;

  setUp(() async {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    final bootstrap = await database.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );
    scope = SyncConflictScope(
      localUserId: bootstrap.activeUserId,
      endpointKey: 'http://server-a:8000',
      cloudUserId: 'cloud-user-a',
    );
    const clock = DateTimeService(now: _fixedNow);
    repository = JournalRepositoryImpl(
      database: database,
      dateTimeService: clock,
    );
    conflicts = SyncConflictRepositoryImpl(
      database,
      payloadCodecs: const [JournalSyncPayloadCodec()],
    );
    service = JournalConflictResolutionServiceImpl(database, conflicts, clock);
  });

  tearDown(() => database.close());

  Future<String> createConflictedJournal() async {
    final entry = await repository.saveTodayEntry(
      const JournalSaveData(learning: 'Local Journal'),
    );
    await (database.update(
      database.journalEntries,
    )..where((row) => row.id.equals(entry.id))).write(
      const db.JournalEntriesCompanion(
        syncStatus: Value('conflict'),
        serverVersion: Value(4),
        lastSyncedAt: Value(500),
      ),
    );
    return entry.id;
  }

  Future<SyncConflictRecord> createConflict(String recordId) async {
    final row = await database.select(database.journalEntries).getSingle();
    return conflicts.upsertDetectedConflict(
      SyncConflictDetection(
        scope: scope,
        entityType: SyncEntityType.journal,
        recordId: recordId,
        remoteRecordId: recordId,
        localSnapshot: SyncConflictSnapshot(
          payload: _payloadFromRow(row),
          updatedAt: row.updatedAt,
          deletedAt: row.deletedAt,
          serverVersion: row.serverVersion,
          originDeviceId: row.originDeviceId,
        ),
        remoteSnapshot: const SyncConflictSnapshot(
          payload: _remotePayload,
          updatedAt: 900,
          deletedAt: null,
          serverVersion: 6,
          originDeviceId: _remoteOriginId,
        ),
        remoteOperation: SyncConflictOperation.upsert,
        resolutionStatus: SyncConflictResolutionStatus.unresolved,
        detectedAt: 900,
      ),
    );
  }

  test('Keep Local prepares the server OCC baseline for normal push', () async {
    final recordId = await createConflictedJournal();
    final conflict = await createConflict(recordId);

    await service.requestKeepLocal(scope: scope, conflictId: conflict.id);

    final row = await database.select(database.journalEntries).getSingle();
    final requested = await conflicts.getConflict(scope, conflict.id);
    expect(row.learning, 'Local Journal');
    expect(row.serverVersion, 6);
    expect(row.syncStatus, 'pending');
    expect(
      requested.resolutionStatus,
      SyncConflictResolutionStatus.keepLocalRequested,
    );
    expect((await JournalSyncAdapter(database).collectPending()), hasLength(1));
  });

  test('Adopt Remote applies hydrated content and resolves conflict', () async {
    final recordId = await createConflictedJournal();
    final conflict = await createConflict(recordId);
    await service.requestAdoptRemote(scope: scope, conflictId: conflict.id);
    final adapter = JournalSyncAdapter(database, conflicts, () async => scope);

    final result = await adapter.applyRemoteChanges(
      changes: [
        SyncChange(
          entityType: SyncEntityType.journal,
          operation: SyncOperation.upsert,
          recordId: recordId,
          payload: _remotePayload,
          updatedAt: 900,
          deletedAt: null,
          originDeviceId: _remoteOriginId,
          serverVersion: 6,
        ),
      ],
      syncedAt: 1000,
      pullMode: SyncPullMode.preferRemoteConflictResolution,
    );

    final row = await database.select(database.journalEntries).getSingle();
    final resolved = await conflicts.getConflict(scope, conflict.id);
    expect(result.status, SyncEntityStatus.succeeded);
    expect(row.learning, 'Remote Journal');
    expect(row.serverVersion, 6);
    expect(row.syncStatus, 'synced');
    expect(
      resolved.resolutionStatus,
      SyncConflictResolutionStatus.resolvedAdoptRemote,
    );
  });

  test(
    'Adopt Remote converges while another Journal conflict remains active',
    () async {
      final recordId = await createConflictedJournal();
      final target = await createConflict(recordId);
      await service.requestAdoptRemote(scope: scope, conflictId: target.id);
      final otherRepository = JournalRepositoryImpl(
        database: database,
        dateTimeService: DateTimeService(now: () => DateTime(2026, 7, 29, 8)),
      );
      final otherEntry = await otherRepository.saveTodayEntry(
        const JournalSaveData(learning: 'Other local Journal'),
      );
      final other = await (database.select(
        database.journalEntries,
      )..where((row) => row.id.equals(otherEntry.id))).getSingle();
      final adapter = JournalSyncAdapter(
        database,
        conflicts,
        () async => scope,
      );

      final result = await adapter.applyRemoteChanges(
        changes: [
          SyncChange(
            entityType: SyncEntityType.journal,
            operation: SyncOperation.upsert,
            recordId: recordId,
            payload: _remotePayload,
            updatedAt: 900,
            deletedAt: null,
            originDeviceId: _remoteOriginId,
            serverVersion: 6,
          ),
          SyncChange(
            entityType: SyncEntityType.journal,
            operation: SyncOperation.upsert,
            recordId: other.id,
            payload: _payloadFromRow(other),
            updatedAt: 901,
            deletedAt: null,
            originDeviceId: _remoteOriginId,
            serverVersion: 7,
          ),
        ],
        syncedAt: 1_000,
        pullMode: SyncPullMode.preferRemoteConflictResolution,
      );

      expect(result.status, SyncEntityStatus.conflict);
      expect(result.pulledCount, 1);
      expect(result.conflictCount, 1);
      expect(
        (await conflicts.getConflict(scope, target.id)).resolutionStatus,
        SyncConflictResolutionStatus.resolvedAdoptRemote,
      );
      final active = await conflicts.listActiveConflicts(scope);
      expect(active, hasLength(1));
      expect(active.single.recordId, other.id);
    },
  );
}

DateTime _fixedNow() => DateTime(2026, 7, 28, 8);

const _remoteOriginId = '43333333-3333-4333-8333-333333333333';

const _remotePayload = JournalSyncPayload(
  entryDate: '2026-07-28',
  timezoneOffsetMinutes: 480,
  mostImportantAccomplishment: 'Remote accomplishment',
  mostDrainingEvent: null,
  emotionSource: null,
  learning: 'Remote Journal',
  tomorrowAdjustment: null,
  status: JournalEntryStatus.completed,
  createdAt: 10,
);

JournalSyncPayload _payloadFromRow(db.JournalEntry row) {
  return JournalSyncPayload(
    entryDate: row.entryDate,
    timezoneOffsetMinutes: row.timezoneOffsetMinutes,
    mostImportantAccomplishment: row.mostImportantAccomplishment,
    mostDrainingEvent: row.mostDrainingEvent,
    emotionSource: row.emotionSource,
    learning: row.learning,
    tomorrowAdjustment: row.tomorrowAdjustment,
    status: switch (row.entryStatus) {
      'draft' => JournalEntryStatus.draft,
      'completed' => JournalEntryStatus.completed,
      _ => throw StateError('Unexpected Journal status'),
    },
    createdAt: row.createdAt,
  );
}
