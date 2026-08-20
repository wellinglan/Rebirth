import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/health/data/health_repository_impl.dart';
import 'package:rebirth/features/health/data/health_sync_adapter.dart';
import 'package:rebirth/features/health/data/health_sync_payload_codec.dart';
import 'package:rebirth/features/health/domain/health_repository.dart';
import 'package:rebirth/features/health/domain/health_save_data.dart';
import 'package:rebirth/features/health/domain/health_sync_payload.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

void main() {
  late AppDatabase database;
  late HealthRepositoryImpl repository;
  late HealthSyncAdapter adapter;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = HealthRepositoryImpl(
      database: database,
      dateTimeService: DateTimeService(now: () => DateTime(2026, 7, 28, 8)),
    );
    adapter = HealthSyncAdapter(database);
  });

  tearDown(() => database.close());

  test('codec round-trips the exact typed Health payload', () {
    const codec = HealthSyncPayloadCodec();
    final encoded = codec.encode(_payload());
    final decoded = codec.decode(recordId: _remoteId, json: encoded);

    expect(encoded.keys, {
      'created_at',
      'data_source',
      'exercise_description',
      'exercise_duration_minutes',
      'exercise_type',
      'note',
      'physical_state_score',
      'physical_state_score_scale',
      'physical_state_description',
      'record_date',
      'sleep_description',
      'sleep_duration_minutes',
      'source_record_id',
      'timezone_offset_minutes',
      'water_intake_ml',
      'water_description',
      'weight_kg',
      'weight_description',
    });
    expect(decoded.recordDate, '2026-07-28');
    expect(decoded.sleepDurationMinutes, 450);
    expect(decoded.sleepDescription, 'Rested well');
    expect(decoded.weightKg, 65.5);
    expect(decoded.weightDescription, isNull);
    expect(decoded.waterDescription, 'Drank steadily');
    expect(decoded.exerciseDescription, 'Easy run');
    expect(decoded.dataSource, 'manual');
  });

  test('codec accepts a legacy Health payload without score scale', () {
    const codec = HealthSyncPayloadCodec();
    final legacy = {...codec.encode(_payload())}
      ..remove('physical_state_score_scale')
      ..remove('physical_state_description')
      ..remove('sleep_description')
      ..remove('weight_description')
      ..remove('water_description')
      ..remove('exercise_description');
    final decoded = codec.decode(recordId: _remoteId, json: legacy);

    expect(decoded.physicalStateScoreScale, 5);
    expect(decoded.physicalStateDescription, isNull);
    expect(decoded.sleepDescription, isNull);
  });

  test('codec accepts Sprint 17B payload without metric narratives', () {
    const codec = HealthSyncPayloadCodec();
    final current = {...codec.encode(_payload())}
      ..remove('sleep_description')
      ..remove('weight_description')
      ..remove('water_description')
      ..remove('exercise_description');
    final decoded = codec.decode(recordId: _remoteId, json: current);

    expect(decoded.physicalStateScoreScale, 10);
    expect(decoded.sleepDescription, isNull);
  });

  test('codec rejects partial narrative generations and overlong text', () {
    const codec = HealthSyncPayloadCodec();
    final encoded = codec.encode(_payload());

    expect(
      () => codec.decode(
        recordId: _remoteId,
        json: {...encoded}..remove('water_description'),
      ),
      throwsA(isA<SyncException>()),
    );
    expect(
      () => codec.encode(
        HealthSyncPayload(
          recordDate: '2026-07-28',
          timezoneOffsetMinutes: 480,
          sleepDurationMinutes: null,
          sleepDescription: List.filled(81, 'x').join(),
          weightKg: null,
          waterIntakeMl: null,
          exerciseType: null,
          exerciseDurationMinutes: null,
          physicalStateScore: null,
          note: null,
          dataSource: 'manual',
          sourceRecordId: null,
          createdAt: 10,
        ),
      ),
      throwsA(isA<SyncException>()),
    );
  });

  test('blank local placeholder is not uploaded', () async {
    await repository.getToday();

    expect(await adapter.collectPending(), isEmpty);
  });

  test('local save is collected as a typed pending push', () async {
    final entry = await repository.saveForDate(
      HealthSaveData(
        recordDate: '2026-07-28',
        sleepDurationMinutes: 450,
        sleepDescription: 'Rested well',
        waterIntakeMl: 1200,
        waterDescription: 'Drank steadily',
      ),
    );

    final pending = await adapter.collectPending();
    final payload = pending.single.payload! as HealthSyncPayload;

    expect(pending.single.recordId, entry.id);
    expect(pending.single.operation, SyncOperation.upsert);
    expect(pending.single.clientVersion, 0);
    expect(payload.recordDate, '2026-07-28');
    expect(payload.sleepDurationMinutes, 450);
    expect(payload.sleepDescription, 'Rested well');
    expect(payload.waterIntakeMl, 1200);
    expect(payload.waterDescription, 'Drank steadily');
  });

  test(
    'push acknowledgement changes metadata but not Health content',
    () async {
      final entry = await repository.saveForDate(
        HealthSaveData(recordDate: '2026-07-28', note: 'Private local note'),
      );
      final submitted = await adapter.collectPending();

      final result = await adapter.acknowledgePush(
        submitted: submitted,
        accepted: [
          SyncAcknowledgement(
            entityType: SyncEntityType.health,
            recordId: entry.id,
            serverVersion: 7,
          ),
        ],
        conflicts: const [],
        syncedAt: 900,
      );
      final row = await database.select(database.healthRecords).getSingle();

      expect(result.pushedCount, 1);
      expect(row.note, 'Private local note');
      expect(row.syncStatus, 'synced');
      expect(row.serverVersion, 7);
      expect(row.lastSyncedAt, 900);
    },
  );

  test('remote Health pull succeeds without a Today record', () async {
    final result = await adapter.applyRemoteChanges(
      changes: [_remoteChange()],
      syncedAt: 1000,
    );
    final row = await database.select(database.healthRecords).getSingle();

    expect(result.pulledCount, 1);
    expect(row.id, _remoteId);
    expect(row.todayRecordId, isNull);
    expect(row.recordDate, '2026-07-28');
    expect(row.sleepDurationMinutes, 450);
    expect(row.sleepDescription, 'Rested well');
    expect(row.syncStatus, 'synced');
    expect(row.serverVersion, 1);
  });

  test('invalid remote batch rolls back every Health write', () async {
    final invalid = _remoteChange(
      id: _secondRemoteId,
      version: 2,
      payload: const HealthSyncPayload(
        recordDate: '2026-07-29',
        timezoneOffsetMinutes: 480,
        sleepDurationMinutes: -1,
        weightKg: null,
        waterIntakeMl: null,
        exerciseType: null,
        exerciseDurationMinutes: null,
        physicalStateScore: null,
        note: null,
        dataSource: 'manual',
        sourceRecordId: null,
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
    expect(await database.select(database.healthRecords).get(), isEmpty);
  });

  test('local soft delete produces a payload-free tombstone', () async {
    final entry = await repository.saveForDate(
      HealthSaveData(recordDate: '2026-07-28', waterIntakeMl: 0),
    );
    await repository.softDelete(entry.id);

    final pending = await adapter.collectPending();

    expect(pending, hasLength(1));
    expect(pending.single.operation, SyncOperation.delete);
    expect(pending.single.payload, isNull);
    expect(pending.single.deletedAt, isNotNull);
  });

  test('pending local edit conflicts instead of being overwritten', () async {
    final entry = await repository.saveForDate(
      HealthSaveData(recordDate: '2026-07-28', note: 'Initial'),
    );
    await (database.update(
      database.healthRecords,
    )..where((row) => row.id.equals(entry.id))).write(
      const HealthRecordsCompanion(
        syncStatus: Value('synced'),
        serverVersion: Value(1),
      ),
    );
    await repository.saveForDate(
      HealthSaveData(recordDate: '2026-07-28', note: 'Local pending'),
    );

    final result = await adapter.applyRemoteChanges(
      changes: [
        _remoteChange(
          id: entry.id,
          version: 2,
          payload: _payload(note: 'Cloud update'),
        ),
      ],
      syncedAt: 1000,
    );
    final row = await database.select(database.healthRecords).getSingle();

    expect(result.status, SyncEntityStatus.conflict);
    expect(row.note, 'Local pending');
    expect(row.syncStatus, 'conflict');
    await expectLater(
      repository.saveForDate(
        HealthSaveData(recordDate: '2026-07-28', note: 'Bypass'),
      ),
      throwsA(isA<HealthConflictPendingException>()),
    );
    await expectLater(
      repository.softDelete(entry.id),
      throwsA(isA<HealthConflictPendingException>()),
    );
  });

  test(
    'deleting Today leaves Health active and independently syncable',
    () async {
      final bootstrap = await database.bootstrapDao.bootstrap();
      const todayId = '45555555-5555-4555-8555-555555555555';
      await database
          .into(database.todayRecords)
          .insert(
            TodayRecordsCompanion.insert(
              id: const Value(todayId),
              userId: bootstrap.activeUserId,
              recordDate: '2026-07-28',
              timezoneOffsetMinutes: 480,
              createdAt: const Value(10),
              updatedAt: const Value(10),
            ),
          );
      final entry = await repository.saveForDate(
        HealthSaveData(recordDate: '2026-07-28', waterIntakeMl: 1500),
      );
      await (database.update(database.todayRecords)
            ..where((row) => row.id.equals(todayId)))
          .write(const TodayRecordsCompanion(deletedAt: Value(20)));

      final health = await database.select(database.healthRecords).getSingle();
      final pending = await adapter.collectPending();

      expect(health.id, entry.id);
      expect(health.deletedAt, isNull);
      expect(health.todayRecordId, todayId);
      expect(pending.single.entityType, SyncEntityType.health);
    },
  );

  test('Health conflict does not mutate same-day Today content', () async {
    final bootstrap = await database.bootstrapDao.bootstrap();
    const todayId = '46666666-6666-4666-8666-666666666666';
    await database
        .into(database.todayRecords)
        .insert(
          TodayRecordsCompanion.insert(
            id: const Value(todayId),
            userId: bootstrap.activeUserId,
            recordDate: '2026-07-28',
            timezoneOffsetMinutes: 480,
            dailyNote: const Value('Today stays local'),
            createdAt: const Value(10),
            updatedAt: const Value(10),
          ),
        );
    final entry = await repository.saveForDate(
      HealthSaveData(recordDate: '2026-07-28', note: 'Local Health'),
    );
    final result = await adapter.applyRemoteChanges(
      changes: [
        _remoteChange(
          id: entry.id,
          version: 2,
          payload: _payload(note: 'Cloud Health'),
        ),
      ],
      syncedAt: 1000,
    );

    final today = await database.select(database.todayRecords).getSingle();
    expect(result.status, SyncEntityStatus.conflict);
    expect(today.dailyNote, 'Today stays local');
    expect(today.deletedAt, isNull);
  });
}

const _remoteId = '41111111-1111-4111-8111-111111111111';
const _secondRemoteId = '42222222-2222-4222-8222-222222222222';
const _originId = '43333333-3333-4333-8333-333333333333';

HealthSyncPayload _payload({String note = 'Cloud Health'}) {
  return HealthSyncPayload(
    recordDate: '2026-07-28',
    timezoneOffsetMinutes: 480,
    sleepDurationMinutes: 450,
    sleepDescription: 'Rested well',
    weightKg: 65.5,
    weightDescription: null,
    waterIntakeMl: 1500,
    waterDescription: 'Drank steadily',
    exerciseType: 'run',
    exerciseDurationMinutes: 30,
    exerciseDescription: 'Easy run',
    physicalStateScore: 4,
    note: note,
    dataSource: 'manual',
    sourceRecordId: null,
    createdAt: 10,
  );
}

SyncChange _remoteChange({
  String id = _remoteId,
  int version = 1,
  HealthSyncPayload? payload,
}) {
  return SyncChange(
    entityType: SyncEntityType.health,
    operation: SyncOperation.upsert,
    recordId: id,
    payload: payload ?? _payload(),
    updatedAt: 100 + version,
    deletedAt: null,
    originDeviceId: _originId,
    serverVersion: version,
  );
}
