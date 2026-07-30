import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/sync/data/sync_conflict_repository_impl.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/today/data/today_conflict_resolution_service_impl.dart';
import 'package:rebirth/features/today/data/today_repository_impl.dart';
import 'package:rebirth/features/today/data/today_sync_adapter.dart';
import 'package:rebirth/features/today/data/today_sync_payload_codec.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_save_data.dart';
import 'package:rebirth/features/today/domain/today_sync_payload.dart';

void main() {
  late AppDatabase database;
  late TodayRepositoryImpl todayRepository;
  late SyncConflictRepositoryImpl conflictRepository;
  late TodayConflictResolutionServiceImpl service;
  late SyncConflictScope scope;
  late String installationId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final bootstrap = await database.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );
    installationId = bootstrap.localInstallationId;
    scope = SyncConflictScope(
      localUserId: bootstrap.activeUserId,
      endpointKey: 'http://server-a:8000',
      cloudUserId: 'cloud-user-a',
    );
    const clock = DateTimeService(now: _fixedNow);
    todayRepository = TodayRepositoryImpl(
      database: database,
      dateTimeService: clock,
    );
    conflictRepository = SyncConflictRepositoryImpl(
      database,
      payloadCodecs: const [TodaySyncPayloadCodec()],
    );
    service = TodayConflictResolutionServiceImpl(
      database,
      conflictRepository,
      clock,
    );
  });

  Future<TodayRecord?> today(String id) {
    return (database.select(
      database.todayRecords,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<TodayRecord> createLocalToday({bool withHealth = false}) async {
    final entry = await todayRepository.saveToday(
      TodaySaveData(
        dailyNote: 'Local Today',
        researchMinutes: null,
        learningMinutes: 0,
        health: withHealth
            ? const TodayHealthInput(
                sleepDurationMinutes: 450,
                exerciseDurationMinutes: 30,
                physicalStateScore: 4,
              )
            : null,
      ),
    );
    await (database.update(database.todayRecords)
          ..where((row) => row.id.equals(entry.id)))
        .write(
          const TodayRecordsCompanion(
            syncStatus: Value('conflict'),
            serverVersion: Value(4),
            lastSyncedAt: Value(500),
          ),
        );
    return (await today(entry.id))!;
  }

  Future<SyncConflictRecord> createConflict({
    required TodayRecord local,
    String? remoteRecordId,
  }) {
    return conflictRepository.upsertDetectedConflict(
      SyncConflictDetection(
        scope: scope,
        entityType: SyncEntityType.today,
        recordId: local.id,
        remoteRecordId: remoteRecordId ?? local.id,
        localSnapshot: SyncConflictSnapshot(
          payload: _localPayload(local),
          updatedAt: local.updatedAt,
          deletedAt: local.deletedAt,
          serverVersion: local.serverVersion,
          originDeviceId: local.originDeviceId,
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

  tearDown(() => database.close());

  test('adopt request is persisted before local Today changes', () async {
    final local = await createLocalToday();
    final conflict = await createConflict(local: local);

    await service.requestAdoptRemote(
      scope: scope,
      conflictId: conflict.id,
    );

    final unchanged = await today(local.id);
    final requested = await conflictRepository.getConflict(scope, conflict.id);
    expect(unchanged!.dailyNote, 'Local Today');
    expect(unchanged.serverVersion, 4);
    expect(
      requested.resolutionStatus,
      SyncConflictResolutionStatus.adoptRemoteRequested,
    );
  });

  test('keep local prepares OCC baseline and resolves after acknowledgement', () async {
    final local = await createLocalToday();
    final conflict = await createConflict(local: local);

    await service.requestKeepLocal(
      scope: scope,
      conflictId: conflict.id,
    );

    final prepared = await today(local.id);
    expect(prepared!.dailyNote, 'Local Today');
    expect(prepared.serverVersion, 6);
    expect(prepared.syncStatus, 'pending');
    expect(prepared.originDeviceId, installationId);
    expect(
      (await conflictRepository.getConflict(scope, conflict.id))
          .resolutionStatus,
      SyncConflictResolutionStatus.keepLocalRequested,
    );

    final adapter = TodaySyncAdapter(
      database,
      conflictRepository,
      () async => scope,
    );
    final submitted = await adapter.collectPending();
    await adapter.acknowledgePush(
      submitted: submitted,
      accepted: [
        SyncAcknowledgement(
          entityType: SyncEntityType.today,
          recordId: local.id,
          serverVersion: 7,
        ),
      ],
      conflicts: const [],
      syncedAt: 1_000,
    );

    expect((await today(local.id))!.syncStatus, 'synced');
    expect(
      (await conflictRepository.getConflict(scope, conflict.id))
          .resolutionStatus,
      SyncConflictResolutionStatus.resolvedKeepLocal,
    );
  });

  test('keep local rekeys a same-date collision and preserves Health', () async {
    final local = await createLocalToday(withHealth: true);
    final healthBefore = await database.select(database.healthRecords).getSingle();
    final conflict = await createConflict(
      local: local,
      remoteRecordId: _remoteId,
    );

    await service.requestKeepLocal(
      scope: scope,
      conflictId: conflict.id,
    );

    final rows = await database.select(database.todayRecords).get();
    final abandoned = rows.singleWhere((row) => row.id == local.id);
    final canonical = rows.singleWhere((row) => row.id == _remoteId);
    final healthAfter = await database.select(database.healthRecords).getSingle();
    expect(abandoned.deletedAt, isNotNull);
    expect(abandoned.syncStatus, 'synced');
    expect(canonical.deletedAt, isNull);
    expect(canonical.dailyNote, 'Local Today');
    expect(canonical.serverVersion, 6);
    expect(canonical.syncStatus, 'pending');
    expect(healthAfter.todayRecordId, _remoteId);
    expect(healthAfter.sleepDurationMinutes, healthBefore.sleepDurationMinutes);
    expect(healthAfter.updatedAt, healthBefore.updatedAt);
    expect(healthAfter.syncStatus, healthBefore.syncStatus);
    expect((await TodaySyncAdapter(database).collectPending()).single.recordId, _remoteId);
  });

  test('adopt remote converges a same-date collision transactionally', () async {
    final local = await createLocalToday(withHealth: true);
    final healthBefore = await database.select(database.healthRecords).getSingle();
    final conflict = await createConflict(
      local: local,
      remoteRecordId: _remoteId,
    );
    await service.requestAdoptRemote(
      scope: scope,
      conflictId: conflict.id,
    );
    final adapter = TodaySyncAdapter(
      database,
      conflictRepository,
      () async => scope,
    );

    final result = await adapter.applyRemoteChanges(
      changes: [_remoteChange()],
      syncedAt: 1_000,
      pullMode: SyncPullMode.preferRemoteConflictResolution,
    );

    final active =
        await (database.select(database.todayRecords)
              ..where((row) => row.deletedAt.isNull()))
            .getSingle();
    final healthAfter = await database.select(database.healthRecords).getSingle();
    final resolved = await conflictRepository.getConflict(scope, conflict.id);
    expect(result.status, SyncEntityStatus.succeeded);
    expect(active.id, _remoteId);
    expect(active.dailyNote, 'Remote Today');
    expect(active.serverVersion, 6);
    expect(healthAfter.todayRecordId, _remoteId);
    expect(healthAfter.sleepDurationMinutes, healthBefore.sleepDurationMinutes);
    expect(healthAfter.updatedAt, healthBefore.updatedAt);
    expect(
      resolved.resolutionStatus,
      SyncConflictResolutionStatus.resolvedAdoptRemote,
    );
    expect(resolved.localSnapshot.payload, isA<TodaySyncPayload>());
  });

  test(
    'adopt remote converges while another Today conflict remains active',
    () async {
      final local = await createLocalToday();
      final target = await createConflict(
        local: local,
        remoteRecordId: _remoteId,
      );
      await service.requestAdoptRemote(scope: scope, conflictId: target.id);
      final otherRepository = TodayRepositoryImpl(
        database: database,
        dateTimeService: DateTimeService(now: () => DateTime(2026, 7, 29, 8)),
      );
      final otherEntry = await otherRepository.saveToday(
        TodaySaveData(dailyNote: 'Other local Today'),
      );
      final other = (await today(otherEntry.id))!;
      final adapter = TodaySyncAdapter(
        database,
        conflictRepository,
        () async => scope,
      );

      final result = await adapter.applyRemoteChanges(
        changes: [
          _remoteChange(),
          SyncChange(
            entityType: SyncEntityType.today,
            operation: SyncOperation.upsert,
            recordId: other.id,
            payload: _localPayload(other),
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
        (await conflictRepository.getConflict(
          scope,
          target.id,
        )).resolutionStatus,
        SyncConflictResolutionStatus.resolvedAdoptRemote,
      );
      final active = await conflictRepository.listActiveConflicts(scope);
      expect(active, hasLength(1));
      expect(active.single.recordId, other.id);
    },
  );

  test(
    'adopt remote selects the requested duplicate remote conflict',
    () async {
      final targetLocal = await createLocalToday();
      final target = await createConflict(
        local: targetLocal,
        remoteRecordId: _remoteId,
      );
      await service.requestAdoptRemote(scope: scope, conflictId: target.id);

      final otherRepository = TodayRepositoryImpl(
        database: database,
        dateTimeService: DateTimeService(now: () => DateTime(2026, 7, 29, 8)),
      );
      final otherEntry = await otherRepository.saveToday(
        TodaySaveData(dailyNote: 'Other local Today'),
      );
      final other = (await today(otherEntry.id))!;
      final otherConflict = await createConflict(
        local: other,
        remoteRecordId: _remoteId,
      );
      final adapter = TodaySyncAdapter(
        database,
        conflictRepository,
        () async => scope,
      );

      final result = await adapter.applyRemoteChanges(
        changes: [_remoteChange()],
        syncedAt: 1_000,
        pullMode: SyncPullMode.preferRemoteConflictResolution,
      );

      expect(result.status, SyncEntityStatus.succeeded);
      expect(
        (await conflictRepository.getConflict(
          scope,
          target.id,
        )).resolutionStatus,
        SyncConflictResolutionStatus.resolvedAdoptRemote,
      );
      expect(
        (await conflictRepository.getConflict(
          scope,
          otherConflict.id,
        )).resolutionStatus,
        SyncConflictResolutionStatus.unresolved,
      );
    },
  );

  test('full pull hydrates an awaiting conflict without changing local data', () async {
    final local = await createLocalToday();
    final conflict = await conflictRepository.upsertDetectedConflict(
      SyncConflictDetection(
        scope: scope,
        entityType: SyncEntityType.today,
        recordId: local.id,
        remoteRecordId: _remoteId,
        localSnapshot: SyncConflictSnapshot(
          payload: _localPayload(local),
          updatedAt: local.updatedAt,
          deletedAt: null,
          serverVersion: local.serverVersion,
          originDeviceId: local.originDeviceId,
        ),
        remoteSnapshot: const SyncConflictSnapshot(
          payload: null,
          updatedAt: null,
          deletedAt: null,
          serverVersion: 6,
          originDeviceId: null,
        ),
        remoteOperation: SyncConflictOperation.unknownPendingPull,
        resolutionStatus:
            SyncConflictResolutionStatus.awaitingRemoteSnapshot,
        detectedAt: 900,
      ),
    );
    final adapter = TodaySyncAdapter(
      database,
      conflictRepository,
      () async => scope,
    );

    final result = await adapter.applyRemoteChanges(
      changes: [_remoteChange()],
      syncedAt: 1_000,
      pullMode: SyncPullMode.preferRemoteConflictResolution,
    );

    final hydrated = await conflictRepository.getConflict(scope, conflict.id);
    expect(result.status, SyncEntityStatus.conflict);
    expect(hydrated.remoteRecordId, _remoteId);
    expect(
      hydrated.resolutionStatus,
      SyncConflictResolutionStatus.unresolved,
    );
    expect((hydrated.remoteSnapshot.payload as TodaySyncPayload).dailyNote, 'Remote Today');
    expect((await today(local.id))!.dailyNote, 'Local Today');
  });

  test('adopt remote tombstone soft deletes Today and preserves Health', () async {
    final local = await createLocalToday(withHealth: true);
    final healthBefore = await database.select(database.healthRecords).getSingle();
    final conflict = await createConflict(local: local);
    await service.requestAdoptRemote(
      scope: scope,
      conflictId: conflict.id,
    );
    final adapter = TodaySyncAdapter(
      database,
      conflictRepository,
      () async => scope,
    );

    final result = await adapter.applyRemoteChanges(
      changes: [
        SyncChange(
          entityType: SyncEntityType.today,
          operation: SyncOperation.delete,
          recordId: local.id,
          payload: null,
          updatedAt: 950,
          deletedAt: 950,
          originDeviceId: _remoteOriginId,
          serverVersion: 7,
        ),
      ],
      syncedAt: 1_000,
      pullMode: SyncPullMode.preferRemoteConflictResolution,
    );

    final deleted = await today(local.id);
    final healthAfter = await database.select(database.healthRecords).getSingle();
    expect(result.deletedCount, 1);
    expect(deleted!.deletedAt, 950);
    expect(deleted.serverVersion, 7);
    expect(healthAfter, healthBefore);
    expect(
      (await conflictRepository.getConflict(scope, conflict.id))
          .resolutionStatus,
      SyncConflictResolutionStatus.resolvedAdoptRemote,
    );
  });

}

DateTime _fixedNow() => DateTime(2026, 7, 28, 8);

const _remoteId = '11111111-1111-4111-8111-111111111111';
const _remoteOriginId = '22222222-2222-4222-8222-222222222222';

TodaySyncPayload _localPayload(TodayRecord row) {
  return TodaySyncPayload(
    recordDate: row.recordDate,
    timezoneOffsetMinutes: row.timezoneOffsetMinutes,
    priority1: row.priority1,
    priority1Completed: row.priority1Completed,
    priority1GoalId: row.priority1GoalId,
    priority2: row.priority2,
    priority2Completed: row.priority2Completed,
    priority2GoalId: row.priority2GoalId,
    priority3: row.priority3,
    priority3Completed: row.priority3Completed,
    priority3GoalId: row.priority3GoalId,
    moodScore: row.moodScore,
    energyScore: row.energyScore,
    researchMinutes: row.researchMinutes,
    learningMinutes: row.learningMinutes,
    dailyNote: row.dailyNote,
    status: TodayRecordStatus.draft,
    createdAt: row.createdAt,
  );
}

const _remotePayload = TodaySyncPayload(
  recordDate: '2026-07-28',
  timezoneOffsetMinutes: 480,
  priority1: 'Remote priority',
  priority1Completed: true,
  priority1GoalId: null,
  priority2: null,
  priority2Completed: false,
  priority2GoalId: null,
  priority3: null,
  priority3Completed: false,
  priority3GoalId: null,
  moodScore: 5,
  energyScore: 4,
  researchMinutes: 120,
  learningMinutes: 30,
  dailyNote: 'Remote Today',
  status: TodayRecordStatus.completed,
  createdAt: 100,
);

SyncChange _remoteChange() {
  return const SyncChange(
    entityType: SyncEntityType.today,
    operation: SyncOperation.upsert,
    recordId: _remoteId,
    payload: _remotePayload,
    updatedAt: 900,
    deletedAt: null,
    originDeviceId: _remoteOriginId,
    serverVersion: 6,
  );
}
