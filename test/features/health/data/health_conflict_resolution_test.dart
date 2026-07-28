import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/health/data/health_conflict_resolution_service_impl.dart';
import 'package:rebirth/features/health/data/health_repository_impl.dart';
import 'package:rebirth/features/health/data/health_sync_adapter.dart';
import 'package:rebirth/features/health/data/health_sync_payload_codec.dart';
import 'package:rebirth/features/health/domain/health_save_data.dart';
import 'package:rebirth/features/health/domain/health_sync_payload.dart';
import 'package:rebirth/features/sync/data/sync_conflict_repository_impl.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

void main() {
  late db.AppDatabase database;
  late HealthRepositoryImpl repository;
  late SyncConflictRepositoryImpl conflicts;
  late HealthConflictResolutionServiceImpl service;
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
    repository = HealthRepositoryImpl(
      database: database,
      dateTimeService: clock,
    );
    conflicts = SyncConflictRepositoryImpl(
      database,
      payloadCodecs: const [HealthSyncPayloadCodec()],
    );
    service = HealthConflictResolutionServiceImpl(database, conflicts, clock);
  });

  tearDown(() => database.close());

  Future<String> createConflictedHealth() async {
    final entry = await repository.saveForDate(
      HealthSaveData(
        recordDate: '2026-07-28',
        sleepDurationMinutes: 420,
        note: 'Local Health',
      ),
    );
    await (database.update(
      database.healthRecords,
    )..where((row) => row.id.equals(entry.id))).write(
      const db.HealthRecordsCompanion(
        syncStatus: Value('conflict'),
        serverVersion: Value(4),
        lastSyncedAt: Value(500),
      ),
    );
    return entry.id;
  }

  Future<SyncConflictRecord> createConflict(String recordId) async {
    final row = await database.select(database.healthRecords).getSingle();
    return conflicts.upsertDetectedConflict(
      SyncConflictDetection(
        scope: scope,
        entityType: SyncEntityType.health,
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
    final recordId = await createConflictedHealth();
    final conflict = await createConflict(recordId);

    await service.requestKeepLocal(scope: scope, conflictId: conflict.id);

    final row = await database.select(database.healthRecords).getSingle();
    final requested = await conflicts.getConflict(scope, conflict.id);
    expect(row.note, 'Local Health');
    expect(row.serverVersion, 6);
    expect(row.syncStatus, 'pending');
    expect(
      requested.resolutionStatus,
      SyncConflictResolutionStatus.keepLocalRequested,
    );
    expect((await HealthSyncAdapter(database).collectPending()), hasLength(1));
  });

  test('Adopt Remote applies content and resolves the conflict', () async {
    final recordId = await createConflictedHealth();
    final conflict = await createConflict(recordId);
    await service.requestAdoptRemote(scope: scope, conflictId: conflict.id);
    final adapter = HealthSyncAdapter(database, conflicts, () async => scope);

    final result = await adapter.applyRemoteChanges(
      changes: [
        SyncChange(
          entityType: SyncEntityType.health,
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

    final row = await database.select(database.healthRecords).getSingle();
    final resolved = await conflicts.getConflict(scope, conflict.id);
    expect(result.status, SyncEntityStatus.succeeded);
    expect(row.note, 'Remote Health');
    expect(row.sleepDurationMinutes, 450);
    expect(row.serverVersion, 6);
    expect(row.syncStatus, 'synced');
    expect(
      resolved.resolutionStatus,
      SyncConflictResolutionStatus.resolvedAdoptRemote,
    );
  });
}

DateTime _fixedNow() => DateTime(2026, 7, 28, 8);

const _remoteOriginId = '43333333-3333-4333-8333-333333333333';

const _remotePayload = HealthSyncPayload(
  recordDate: '2026-07-28',
  timezoneOffsetMinutes: 480,
  sleepDurationMinutes: 450,
  weightKg: 65.5,
  waterIntakeMl: 1500,
  exerciseType: 'run',
  exerciseDurationMinutes: 30,
  physicalStateScore: 4,
  note: 'Remote Health',
  dataSource: 'manual',
  sourceRecordId: null,
  createdAt: 10,
);

HealthSyncPayload _payloadFromRow(db.HealthRecord row) {
  return HealthSyncPayload(
    recordDate: row.recordDate,
    timezoneOffsetMinutes: row.timezoneOffsetMinutes,
    sleepDurationMinutes: row.sleepDurationMinutes,
    weightKg: row.weightKg,
    waterIntakeMl: row.waterIntakeMl,
    exerciseType: row.exerciseType,
    exerciseDurationMinutes: row.exerciseDurationMinutes,
    physicalStateScore: row.physicalStateScore,
    note: row.note,
    dataSource: row.dataSource,
    sourceRecordId: row.sourceRecordId,
    createdAt: row.createdAt,
  );
}
