import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/sync/data/sync_conflict_repository_impl.dart';
import 'package:rebirth/features/sync/domain/sync_conflict.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/today/data/today_repository_impl.dart';
import 'package:rebirth/features/today/data/today_sync_adapter.dart';
import 'package:rebirth/features/today/data/today_sync_payload_codec.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_save_data.dart';
import 'package:rebirth/features/today/domain/today_sync_payload.dart';

void main() {
  late AppDatabase database;
  late TodayRepositoryImpl repository;
  late TodaySyncAdapter adapter;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = TodayRepositoryImpl(
      database: database,
      dateTimeService: DateTimeService(now: () => DateTime(2026, 7, 28, 8)),
    );
    adapter = TodaySyncAdapter(database);
  });

  tearDown(() => database.close());

  test('saved Today becomes pending and encodes typed business data', () async {
    final entry = await repository.saveToday(
      TodaySaveData(
        priorities: const [TodayPriority(text: 'Research', completed: true)],
        researchMinutes: 90,
        researchDescription: 'Focused research',
        learningMinutes: 0,
        learningDescription: 'Reviewed notes',
        dailyNote: null,
      ),
    );

    final pending = await adapter.collectPending();
    final payload = pending.single.payload! as TodaySyncPayload;
    final encoded = adapter.encodePayload(payload);
    final raw = await database.select(database.todayRecords).getSingle();

    expect(pending.single.recordId, entry.id);
    expect(pending.single.operation, SyncOperation.upsert);
    expect(pending.single.clientVersion, 0);
    expect(payload.recordDate, '2026-07-28');
    expect(payload.researchMinutes, 90);
    expect(payload.researchDescription, 'Focused research');
    expect(payload.learningMinutes, 0);
    expect(payload.learningDescription, 'Reviewed notes');
    expect(payload.dailyNote, isNull);
    expect(encoded, isNot(contains('health')));
    expect(raw.syncStatus, 'pending');
  });

  test('blank view-created Today is not uploaded', () async {
    await repository.getToday();

    expect(await adapter.collectPending(), isEmpty);
  });

  test('local Today tombstone is collected without business payload', () async {
    final entry = await repository.saveToday(
      TodaySaveData(dailyNote: 'Delete locally'),
    );
    await (database.update(
      database.todayRecords,
    )..where((row) => row.id.equals(entry.id))).write(
      const TodayRecordsCompanion(
        updatedAt: Value(200),
        deletedAt: Value(200),
        syncStatus: Value('pending'),
      ),
    );

    final pending = await adapter.collectPending();

    expect(pending, hasLength(1));
    expect(pending.single.operation, SyncOperation.delete);
    expect(pending.single.payload, isNull);
    expect(pending.single.deletedAt, 200);
  });

  test('acknowledgement updates only Today sync metadata', () async {
    final entry = await repository.saveToday(
      TodaySaveData(dailyNote: 'Keep me'),
    );
    final submitted = await adapter.collectPending();

    final result = await adapter.acknowledgePush(
      submitted: submitted,
      accepted: [
        SyncAcknowledgement(
          entityType: SyncEntityType.today,
          recordId: entry.id,
          serverVersion: 7,
        ),
      ],
      conflicts: const [],
      syncedAt: 900,
    );
    final raw = await database.select(database.todayRecords).getSingle();

    expect(result.pushedCount, 1);
    expect(raw.dailyNote, 'Keep me');
    expect(raw.syncStatus, 'synced');
    expect(raw.serverVersion, 7);
    expect(raw.lastSyncedAt, 900);
  });

  test('remote Today safely replaces an empty same-date placeholder', () async {
    final placeholder = await repository.getToday();

    final result = await adapter.applyRemoteChanges(
      changes: [_remoteChange(note: 'Cloud Today')],
      syncedAt: 1000,
    );
    final rows = await database.select(database.todayRecords).get();
    final loaded = await repository.getByDate('2026-07-28');

    expect(result.pulledCount, 1);
    expect(rows, hasLength(1));
    expect(rows.single.id, _remoteId);
    expect(rows.single.id, isNot(placeholder.id));
    expect(rows.single.syncStatus, 'synced');
    expect(loaded?.dailyNote, 'Cloud Today');
    expect(loaded?.researchDescription, 'Cloud research');
    expect(loaded?.learningDescription, 'Cloud learning');
  });

  test(
    'remote Today does not assume a placeholder has at most one linked Health',
    () async {
      final placeholder = await repository.getToday();
      final bootstrap = await database.bootstrapDao.bootstrap();
      for (final (index, id) in [
        '21111111-1111-4111-8111-111111111111',
        '31111111-1111-4111-8111-111111111111',
      ].indexed) {
        await database
            .into(database.healthRecords)
            .insert(
              HealthRecordsCompanion.insert(
                id: Value(id),
                userId: bootstrap.activeUserId,
                todayRecordId: Value(placeholder.id),
                recordDate: '2026-07-28',
                timezoneOffsetMinutes: 480,
                createdAt: Value(10 + index),
                updatedAt: Value(10 + index),
                deletedAt: Value(20 + index),
              ),
            );
      }

      final result = await adapter.applyRemoteChanges(
        changes: [_remoteChange(note: 'Cloud Today')],
        syncedAt: 1000,
      );
      final rows = await database.select(database.todayRecords).get();

      expect(result.status, SyncEntityStatus.conflict);
      expect(rows, hasLength(1));
      expect(rows.single.id, placeholder.id);
      expect(await database.select(database.healthRecords).get(), hasLength(2));
    },
  );

  test('remote Today update preserves local Health aggregate', () async {
    final entry = await repository.saveToday(
      TodaySaveData(
        dailyNote: 'Old Today',
        health: const TodayHealthInput(
          sleepDurationMinutes: 450,
          waterIntakeMl: 1200,
          note: 'Health stays local',
        ),
      ),
    );
    await _markSynced(database, entry.id, version: 1);

    await adapter.applyRemoteChanges(
      changes: [
        _remoteChange(id: entry.id, note: 'New cloud Today', version: 2),
      ],
      syncedAt: 1000,
    );
    final loaded = await repository.getByDate('2026-07-28');

    expect(loaded?.dailyNote, 'New cloud Today');
    expect(loaded?.health?.sleepDurationMinutes, 450);
    expect(loaded?.health?.waterIntakeMl, 1200);
    expect(loaded?.health?.note, 'Health stays local');
  });

  test(
    'pending local change creates a generic conflict and stays intact',
    () async {
      final entry = await repository.saveToday(
        TodaySaveData(dailyNote: 'Initial'),
      );
      await _markSynced(database, entry.id, version: 1);
      await repository.updateDailyNote(
        recordDate: entry.recordDate,
        dailyNote: 'Local pending',
      );
      const scope = SyncConflictScope(
        localUserId: 'unused-until-bootstrap',
        endpointKey: 'http://server.test',
        cloudUserId: 'cloud-user',
      );
      final bootstrap = await database.bootstrapDao.bootstrap();
      final actualScope = SyncConflictScope(
        localUserId: bootstrap.activeUserId,
        endpointKey: scope.endpointKey,
        cloudUserId: scope.cloudUserId,
      );
      final conflicts = SyncConflictRepositoryImpl(
        database,
        payloadCodecs: const [TodaySyncPayloadCodec()],
      );
      final conflictAdapter = TodaySyncAdapter(
        database,
        conflicts,
        () async => actualScope,
      );

      final result = await conflictAdapter.applyRemoteChanges(
        changes: [
          _remoteChange(id: entry.id, note: 'Cloud update', version: 2),
        ],
        syncedAt: 1000,
      );
      final raw = await database.select(database.todayRecords).getSingle();
      final records = await conflicts.listActiveConflicts(actualScope);

      expect(result.status, SyncEntityStatus.conflict);
      expect(raw.dailyNote, 'Local pending');
      expect(raw.syncStatus, 'conflict');
      expect(records, hasLength(1));
      expect(records.single.entityType, SyncEntityType.today);
      expect(
        (records.single.remoteSnapshot.payload! as TodaySyncPayload).dailyNote,
        'Cloud update',
      );
    },
  );

  test(
    'same-date content with a different UUID is never overwritten',
    () async {
      final local = await repository.saveToday(
        TodaySaveData(dailyNote: 'Local date owner'),
      );

      final result = await adapter.applyRemoteChanges(
        changes: [_remoteChange(note: 'Different cloud UUID')],
        syncedAt: 1000,
      );
      final rows = await database.select(database.todayRecords).get();

      expect(result.status, SyncEntityStatus.conflict);
      expect(rows, hasLength(1));
      expect(rows.single.id, local.id);
      expect(rows.single.dailyNote, 'Local date owner');
      expect(rows.single.syncStatus, 'conflict');
    },
  );

  test('remote tombstone soft deletes a synced Today record', () async {
    final entry = await repository.saveToday(
      TodaySaveData(
        dailyNote: 'Delete remotely',
        health: const TodayHealthInput(
          sleepDurationMinutes: 420,
          note: 'Local health survives',
        ),
      ),
    );
    await _markSynced(database, entry.id, version: 1);

    final result = await adapter.applyRemoteChanges(
      changes: [
        SyncChange(
          entityType: SyncEntityType.today,
          operation: SyncOperation.delete,
          recordId: entry.id,
          payload: null,
          updatedAt: 200,
          deletedAt: 200,
          originDeviceId: _originId,
          serverVersion: 2,
        ),
      ],
      syncedAt: 1000,
    );
    final raw = await database.select(database.todayRecords).getSingle();

    expect(result.deletedCount, 1);
    expect(raw.deletedAt, 200);
    expect(raw.syncStatus, 'synced');
    expect(raw.serverVersion, 2);

    final replacement = await repository.getToday();
    expect(replacement.id, isNot(entry.id));
    expect(replacement.dailyNote, isNull);
    expect(replacement.health?.sleepDurationMinutes, 420);
    expect(replacement.health?.note, 'Local health survives');
  });

  test('invalid remote Goal reference rolls back the Today batch', () async {
    final change = _remoteChange(
      payload: _payload(priority1GoalId: _missingGoalId),
    );

    await expectLater(
      adapter.applyRemoteChanges(changes: [change], syncedAt: 1000),
      throwsA(isA<SyncException>()),
    );
    expect(await database.select(database.todayRecords).get(), isEmpty);
  });

  test('stale push conflict keeps local null and zero values', () async {
    final entry = await repository.saveToday(
      TodaySaveData(researchMinutes: null, learningMinutes: 0),
    );
    final submitted = await adapter.collectPending();

    final result = await adapter.acknowledgePush(
      submitted: submitted,
      accepted: const [],
      conflicts: [
        SyncConflict(
          tableName: SyncEntityType.today.wireName,
          recordId: entry.id,
          serverVersion: 4,
          reason: 'stale_client',
        ),
      ],
      syncedAt: 900,
    );
    final raw = await database.select(database.todayRecords).getSingle();

    expect(result.status, SyncEntityStatus.conflict);
    expect(raw.researchMinutes, isNull);
    expect(raw.learningMinutes, 0);
    expect(raw.syncStatus, 'conflict');
  });
}

const _remoteId = '11111111-1111-4111-8111-111111111111';
const _originId = '22222222-2222-4222-8222-222222222222';
const _missingGoalId = '33333333-3333-4333-8333-333333333333';

TodaySyncPayload _payload({String? priority1GoalId}) {
  return TodaySyncPayload(
    recordDate: '2026-07-28',
    timezoneOffsetMinutes: 480,
    priority1: priority1GoalId == null ? 'Research' : 'Linked research',
    priority1Completed: false,
    priority1GoalId: priority1GoalId,
    priority2: null,
    priority2Completed: false,
    priority2GoalId: null,
    priority3: null,
    priority3Completed: false,
    priority3GoalId: null,
    moodScore: 4,
    energyScore: 3,
    researchMinutes: 90,
    researchDescription: 'Cloud research',
    learningMinutes: 0,
    learningDescription: 'Cloud learning',
    dailyNote: 'Cloud Today',
    status: TodayRecordStatus.draft,
    createdAt: 10,
  );
}

SyncChange _remoteChange({
  String id = _remoteId,
  String note = 'Cloud Today',
  int version = 1,
  TodaySyncPayload? payload,
}) {
  final value = payload ?? _payload();
  return SyncChange(
    entityType: SyncEntityType.today,
    operation: SyncOperation.upsert,
    recordId: id,
    payload: TodaySyncPayload(
      recordDate: value.recordDate,
      timezoneOffsetMinutes: value.timezoneOffsetMinutes,
      priority1: value.priority1,
      priority1Completed: value.priority1Completed,
      priority1GoalId: value.priority1GoalId,
      priority2: value.priority2,
      priority2Completed: value.priority2Completed,
      priority2GoalId: value.priority2GoalId,
      priority3: value.priority3,
      priority3Completed: value.priority3Completed,
      priority3GoalId: value.priority3GoalId,
      moodScore: value.moodScore,
      wellbeingScoreScale: value.wellbeingScoreScale,
      moodDescription: value.moodDescription,
      energyScore: value.energyScore,
      energyDescription: value.energyDescription,
      researchMinutes: value.researchMinutes,
      researchDescription: value.researchDescription,
      learningMinutes: value.learningMinutes,
      learningDescription: value.learningDescription,
      dailyNote: note,
      status: value.status,
      createdAt: value.createdAt,
    ),
    updatedAt: version * 100,
    deletedAt: null,
    originDeviceId: _originId,
    serverVersion: version,
  );
}

Future<void> _markSynced(
  AppDatabase database,
  String id, {
  required int version,
}) {
  return (database.update(
    database.todayRecords,
  )..where((row) => row.id.equals(id))).write(
    TodayRecordsCompanion(
      syncStatus: const Value('synced'),
      serverVersion: Value(version),
      lastSyncedAt: const Value(50),
    ),
  );
}
