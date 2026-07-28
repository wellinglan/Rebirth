import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/journal/data/journal_repository_impl.dart';
import 'package:rebirth/features/journal/data/journal_sync_adapter.dart';
import 'package:rebirth/features/journal/data/journal_sync_payload_codec.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_repository.dart';
import 'package:rebirth/features/journal/domain/journal_save_data.dart';
import 'package:rebirth/features/journal/domain/journal_sync_payload.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';

void main() {
  late AppDatabase database;
  late JournalRepositoryImpl repository;
  late JournalSyncAdapter adapter;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = JournalRepositoryImpl(
      database: database,
      dateTimeService: DateTimeService(now: () => DateTime(2026, 7, 28, 8)),
    );
    adapter = JournalSyncAdapter(database);
  });

  tearDown(() => database.close());

  test('codec round-trips the exact typed Journal payload', () {
    const codec = JournalSyncPayloadCodec();
    final encoded = codec.encode(_payload());
    final decoded = codec.decode(recordId: _remoteId, json: encoded);

    expect(encoded.keys, {
      'created_at',
      'emotion_source',
      'entry_date',
      'entry_status',
      'learning',
      'most_draining_event',
      'most_important_accomplishment',
      'timezone_offset_minutes',
      'tomorrow_adjustment',
    });
    expect(decoded.entryDate, '2026-07-28');
    expect(decoded.learning, 'Cloud learning');
    expect(decoded.status, JournalEntryStatus.completed);
  });

  test('local save is collected as a typed pending push', () async {
    final entry = await repository.saveTodayEntry(
      const JournalSaveData(
        learning: 'Local learning',
        status: JournalEntryStatus.completed,
      ),
    );

    final pending = await adapter.collectPending();
    final payload = pending.single.payload! as JournalSyncPayload;

    expect(pending.single.recordId, entry.id);
    expect(pending.single.operation, SyncOperation.upsert);
    expect(pending.single.clientVersion, 0);
    expect(payload.entryDate, '2026-07-28');
    expect(payload.learning, 'Local learning');
    expect(payload.status, JournalEntryStatus.completed);
  });

  test(
    'push acknowledgement updates sync metadata without content loss',
    () async {
      final entry = await repository.saveTodayEntry(
        const JournalSaveData(learning: 'Keep this'),
      );
      final submitted = await adapter.collectPending();

      final result = await adapter.acknowledgePush(
        submitted: submitted,
        accepted: [
          SyncAcknowledgement(
            entityType: SyncEntityType.journal,
            recordId: entry.id,
            serverVersion: 7,
          ),
        ],
        conflicts: const [],
        syncedAt: 900,
      );
      final row = await database.select(database.journalEntries).getSingle();

      expect(result.pushedCount, 1);
      expect(row.learning, 'Keep this');
      expect(row.syncStatus, 'synced');
      expect(row.serverVersion, 7);
      expect(row.lastSyncedAt, 900);
    },
  );

  test(
    'remote pull inserts Journal and rederives local associations',
    () async {
      final result = await adapter.applyRemoteChanges(
        changes: [_remoteChange()],
        syncedAt: 1000,
      );
      final row = await database.select(database.journalEntries).getSingle();

      expect(result.pulledCount, 1);
      expect(row.id, _remoteId);
      expect(row.entryDate, '2026-07-28');
      expect(row.learning, 'Cloud learning');
      expect(row.syncStatus, 'synced');
      expect(row.serverVersion, 1);
    },
  );

  test('invalid remote batch rolls back all Journal writes', () async {
    final invalid = _remoteChange(
      id: _secondRemoteId,
      version: 2,
      payload: const JournalSyncPayload(
        entryDate: '2026-07-29',
        timezoneOffsetMinutes: 480,
        mostImportantAccomplishment: null,
        mostDrainingEvent: null,
        emotionSource: null,
        learning: null,
        tomorrowAdjustment: null,
        status: JournalEntryStatus.draft,
        createdAt: 10,
      ),
    );

    await expectLater(
      adapter.applyRemoteChanges(
        changes: [_remoteChange(), invalid],
        syncedAt: 1000,
      ),
      throwsA(isA<SyncException>()),
    );
    expect(await database.select(database.journalEntries).get(), isEmpty);
  });

  test('local soft delete produces a payload-free tombstone', () async {
    final entry = await repository.saveTodayEntry(
      const JournalSaveData(learning: 'Delete me'),
    );
    await repository.softDelete(entry.id);

    final pending = await adapter.collectPending();

    expect(pending, hasLength(1));
    expect(pending.single.operation, SyncOperation.delete);
    expect(pending.single.payload, isNull);
    expect(pending.single.deletedAt, isNotNull);
  });

  test('pending local edit conflicts instead of being overwritten', () async {
    final entry = await repository.saveTodayEntry(
      const JournalSaveData(learning: 'Initial'),
    );
    await (database.update(
      database.journalEntries,
    )..where((row) => row.id.equals(entry.id))).write(
      const JournalEntriesCompanion(
        syncStatus: Value('synced'),
        serverVersion: Value(1),
      ),
    );
    await repository.updateEntry(
      id: entry.id,
      data: const JournalSaveData(learning: 'Local pending'),
    );

    final result = await adapter.applyRemoteChanges(
      changes: [
        _remoteChange(
          id: entry.id,
          version: 2,
          payload: _payload(learning: 'Cloud update'),
        ),
      ],
      syncedAt: 1000,
    );
    final row = await database.select(database.journalEntries).getSingle();

    expect(result.status, SyncEntityStatus.conflict);
    expect(row.learning, 'Local pending');
    expect(row.syncStatus, 'conflict');
    await expectLater(
      repository.updateEntry(
        id: entry.id,
        data: const JournalSaveData(learning: 'Bypass conflict'),
      ),
      throwsA(isA<JournalConflictPendingException>()),
    );
    await expectLater(
      repository.softDelete(entry.id),
      throwsA(isA<JournalConflictPendingException>()),
    );
  });
}

const _remoteId = '41111111-1111-4111-8111-111111111111';
const _secondRemoteId = '42222222-2222-4222-8222-222222222222';
const _originId = '43333333-3333-4333-8333-333333333333';

JournalSyncPayload _payload({String learning = 'Cloud learning'}) {
  return JournalSyncPayload(
    entryDate: '2026-07-28',
    timezoneOffsetMinutes: 480,
    mostImportantAccomplishment: 'Cloud accomplishment',
    mostDrainingEvent: null,
    emotionSource: null,
    learning: learning,
    tomorrowAdjustment: null,
    status: JournalEntryStatus.completed,
    createdAt: 10,
  );
}

SyncChange _remoteChange({
  String id = _remoteId,
  int version = 1,
  JournalSyncPayload? payload,
}) {
  return SyncChange(
    entityType: SyncEntityType.journal,
    operation: SyncOperation.upsert,
    recordId: id,
    payload: payload ?? _payload(),
    updatedAt: 100 + version,
    deletedAt: null,
    originDeviceId: _originId,
    serverVersion: version,
  );
}
