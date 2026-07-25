import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/plan/data/plan_repository_impl.dart';
import 'package:rebirth/features/plan/data/plan_sync_adapter.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_goal_save_data.dart';
import 'package:rebirth/features/plan/domain/plan_sync_payload.dart';
import 'package:rebirth/features/sync/domain/sync_conflict.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

void main() {
  late AppDatabase database;
  late PlanRepositoryImpl repository;
  late PlanSyncAdapter adapter;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = PlanRepositoryImpl(
      database: database,
      dateTimeService: DateTimeService(now: () => DateTime.utc(2026, 7, 20, 8)),
    );
    adapter = PlanSyncAdapter(database);
  });

  tearDown(() => database.close());

  test(
    'collectPending uploads parent before child without local owner',
    () async {
      final parent = await _create(repository, 'Parent');
      final child = await _create(repository, 'Child', parentGoalId: parent.id);

      final pending = await adapter.collectPending();
      final encoded = adapter.encodePayload(pending.first.payload!);

      expect(pending.map((item) => item.recordId), [parent.id, child.id]);
      expect(pending.every((item) => item.clientVersion == 0), isTrue);
      expect(encoded, isNot(contains('user_id')));
      expect(encoded, isNot(contains('sync_status')));
      expect(encoded['parent_goal_id'], isNull);
    },
  );

  test('subtree tombstones are collected child before parent', () async {
    final parent = await _create(repository, 'Parent');
    final child = await _create(repository, 'Child', parentGoalId: parent.id);
    await repository.softDelete(parent.id);

    final pending = await adapter.collectPending();

    expect(pending.map((item) => item.recordId), [child.id, parent.id]);
    expect(
      pending.every((item) => item.operation == SyncOperation.delete),
      isTrue,
    );
    expect(pending.every((item) => item.payload == null), isTrue);
  });

  test(
    'acknowledgement updates metadata and preserves business data',
    () async {
      final goal = await _create(repository, 'Keep title');
      final submitted = await adapter.collectPending();

      final result = await adapter.acknowledgePush(
        submitted: submitted,
        accepted: [
          SyncAcknowledgement(
            entityType: SyncEntityType.plan,
            recordId: goal.id,
            serverVersion: 7,
          ),
        ],
        conflicts: const [],
        syncedAt: 900,
      );
      final raw = await database.select(database.goals).getSingle();

      expect(result.pushedCount, 1);
      expect(raw.title, 'Keep title');
      expect(raw.syncStatus, 'synced');
      expect(raw.serverVersion, 7);
      expect(raw.lastSyncedAt, 900);
    },
  );

  test('incomplete acknowledgement rolls back all metadata', () async {
    await _create(repository, 'First');
    await _create(repository, 'Second');
    final submitted = await adapter.collectPending();

    await expectLater(
      adapter.acknowledgePush(
        submitted: submitted,
        accepted: [
          SyncAcknowledgement(
            entityType: SyncEntityType.plan,
            recordId: submitted.first.recordId,
            serverVersion: 2,
          ),
        ],
        conflicts: const [],
        syncedAt: 900,
      ),
      throwsA(isA<SyncException>()),
    );
    final rows = await database.select(database.goals).get();
    expect(rows.every((row) => row.syncStatus == 'local_only'), isTrue);
    expect(rows.every((row) => row.serverVersion == null), isTrue);
  });

  test(
    'remote child and parent apply transactionally with cloud UUIDs',
    () async {
      final child = _remoteChange(
        id: _childId,
        parentId: _parentId,
        title: 'Remote child',
        version: 2,
      );
      final parent = _remoteChange(
        id: _parentId,
        title: 'Remote parent',
        version: 1,
      );

      final result = await adapter.applyRemoteChanges(
        changes: [child, parent],
        syncedAt: 1000,
      );
      final bootstrap = await database.bootstrapDao.bootstrap();
      final rows = await database.select(database.goals).get();

      expect(result.pulledCount, 2);
      expect(rows, hasLength(2));
      expect(rows.every((row) => row.userId == bootstrap.activeUserId), isTrue);
      expect(
        rows.singleWhere((row) => row.id == _childId).parentGoalId,
        _parentId,
      );
      expect(rows.every((row) => row.syncStatus == 'synced'), isTrue);
    },
  );

  test(
    'remote replay is ignored without changing local business data',
    () async {
      final goal = await _create(repository, 'Local title');
      await (database.update(
        database.goals,
      )..where((row) => row.id.equals(goal.id))).write(
        const GoalsCompanion(
          syncStatus: Value('synced'),
          serverVersion: Value(5),
        ),
      );

      final result = await adapter.applyRemoteChanges(
        changes: [
          _remoteChange(id: goal.id, title: 'Old cloud title', version: 5),
        ],
        syncedAt: 1000,
      );
      final raw = await database.select(database.goals).getSingle();

      expect(result.ignoredCount, 1);
      expect(raw.title, 'Local title');
      expect(raw.serverVersion, 5);
    },
  );

  test('local pending conflict preserves the whole remote batch', () async {
    final goal = await _create(repository, 'Unsynced local');

    final result = await adapter.applyRemoteChanges(
      changes: [
        _remoteChange(id: goal.id, title: 'Cloud overwrite', version: 3),
        _remoteChange(id: _parentId, title: 'Unrelated remote', version: 4),
      ],
      syncedAt: 1000,
    );
    final rows = await database.select(database.goals).get();
    final local = rows.single;

    expect(result.status, SyncEntityStatus.conflict);
    expect(result.conflictCount, 1);
    expect(local.title, 'Unsynced local');
    expect(local.syncStatus, 'conflict');
    expect(rows.any((row) => row.id == _parentId), isFalse);
  });

  test('invalid projected hierarchy rolls back all remote changes', () async {
    final orphan = _remoteChange(
      id: _childId,
      parentId: _parentId,
      title: 'Orphan',
      version: 1,
    );

    await expectLater(
      adapter.applyRemoteChanges(changes: [orphan], syncedAt: 1000),
      throwsA(isA<SyncException>()),
    );
    expect(await database.select(database.goals).get(), isEmpty);
  });

  test('remote tombstone for a missing goal stays row-free', () async {
    final result = await adapter.applyRemoteChanges(
      changes: [
        SyncChange(
          entityType: SyncEntityType.plan,
          operation: SyncOperation.delete,
          recordId: _parentId,
          payload: null,
          updatedAt: 20,
          deletedAt: 20,
          originDeviceId: _originId,
          serverVersion: 1,
        ),
      ],
      syncedAt: 1000,
    );

    expect(result.ignoredCount, 1);
    expect(await database.select(database.goals).get(), isEmpty);
  });

  test('pending collection excludes synced and conflict rows', () async {
    final synced = await _create(repository, 'Synced');
    final conflict = await _create(repository, 'Conflict');
    final pendingGoal = await _create(repository, 'Pending');
    final localOnly = await _create(repository, 'Local only');
    await (database.update(
      database.goals,
    )..where((row) => row.id.equals(synced.id))).write(
      const GoalsCompanion(
        syncStatus: Value('synced'),
        serverVersion: Value(1),
      ),
    );
    await (database.update(database.goals)
          ..where((row) => row.id.equals(conflict.id)))
        .write(const GoalsCompanion(syncStatus: Value('conflict')));
    await (database.update(database.goals)
          ..where((row) => row.id.equals(pendingGoal.id)))
        .write(const GoalsCompanion(syncStatus: Value('pending')));

    final collected = await adapter.collectPending();

    expect(collected.map((item) => item.recordId).toSet(), {
      pendingGoal.id,
      localOnly.id,
    });
  });

  test('stale acknowledgement preserves a local tombstone', () async {
    final goal = await _create(repository, 'Local conflict');
    await repository.softDelete(goal.id);
    final submitted = await adapter.collectPending();
    final deletedAt = submitted.single.deletedAt;

    final result = await adapter.acknowledgePush(
      submitted: submitted,
      accepted: const [],
      conflicts: [
        SyncConflict(
          tableName: SyncEntityType.plan.wireName,
          recordId: goal.id,
          serverVersion: 4,
          reason: 'stale_client',
        ),
      ],
      syncedAt: 900,
    );
    final raw = await database.select(database.goals).getSingle();

    expect(result.status, SyncEntityStatus.conflict);
    expect(raw.syncStatus, 'conflict');
    expect(raw.title, 'Local conflict');
    expect(raw.deletedAt, deletedAt);
    expect(raw.serverVersion, isNull);
  });

  test('higher remote upsert and tombstone update a synced goal', () async {
    final goal = await _create(repository, 'Old title');
    await (database.update(
      database.goals,
    )..where((row) => row.id.equals(goal.id))).write(
      const GoalsCompanion(
        syncStatus: Value('synced'),
        serverVersion: Value(1),
      ),
    );

    await adapter.applyRemoteChanges(
      changes: [_remoteChange(id: goal.id, title: 'Cloud title', version: 2)],
      syncedAt: 1000,
    );
    var raw = await database.select(database.goals).getSingle();
    expect(raw.title, 'Cloud title');
    expect(raw.serverVersion, 2);

    final deleted = await adapter.applyRemoteChanges(
      changes: [
        SyncChange(
          entityType: SyncEntityType.plan,
          operation: SyncOperation.delete,
          recordId: goal.id,
          payload: null,
          updatedAt: 300,
          deletedAt: 300,
          originDeviceId: _originId,
          serverVersion: 3,
        ),
      ],
      syncedAt: 1100,
    );
    raw = await database.select(database.goals).getSingle();
    expect(deleted.deletedCount, 1);
    expect(raw.deletedAt, 300);
    expect(raw.syncStatus, 'synced');
    expect(raw.serverVersion, 3);
  });

  test('remote tombstone conflicts with pending local content', () async {
    final goal = await _create(repository, 'Pending local');

    final result = await adapter.applyRemoteChanges(
      changes: [
        SyncChange(
          entityType: SyncEntityType.plan,
          operation: SyncOperation.delete,
          recordId: goal.id,
          payload: null,
          updatedAt: 200,
          deletedAt: 200,
          originDeviceId: _originId,
          serverVersion: 2,
        ),
      ],
      syncedAt: 1000,
    );
    final raw = await database.select(database.goals).getSingle();

    expect(result.status, SyncEntityStatus.conflict);
    expect(raw.title, 'Pending local');
    expect(raw.deletedAt, isNull);
    expect(raw.syncStatus, 'conflict');
  });

  test('decode preserves null fields and accepts an empty tombstone', () {
    final decoded = adapter.decodeRemoteChange(
      recordId: _parentId,
      payload: adapter.encodePayload(_payload(title: 'Decoded')),
      updatedAt: 10,
      deletedAt: null,
      originDeviceId: _originId,
      serverVersion: 1,
    );
    final payload = decoded.payload! as PlanSyncPayload;
    expect(payload.description, isNull);
    expect(payload.parentGoalId, isNull);
    expect(payload.completedAt, isNull);
    expect(payload.archivedAt, isNull);

    final tombstone = adapter.decodeRemoteChange(
      recordId: _parentId,
      payload: const {},
      updatedAt: 20,
      deletedAt: 20,
      originDeviceId: _originId,
      serverVersion: 2,
    );
    expect(tombstone.operation, SyncOperation.delete);
    expect(tombstone.payload, isNull);
  });

  test('decode rejects missing fields and inconsistent completion', () {
    expect(
      () => adapter.decodeRemoteChange(
        recordId: _parentId,
        payload: const {'title': 'Missing'},
        updatedAt: 1,
        deletedAt: null,
        originDeviceId: _originId,
        serverVersion: 1,
      ),
      throwsA(isA<SyncException>()),
    );
    expect(
      () => adapter.decodeRemoteChange(
        recordId: _parentId,
        payload: {
          ...adapter.encodePayload(_payload(title: 'Bad completion')),
          'status': 'completed',
          'completed_at': null,
        },
        updatedAt: 1,
        deletedAt: null,
        originDeviceId: _originId,
        serverVersion: 1,
      ),
      throwsA(isA<SyncException>()),
    );
  });
}

const _parentId = '11111111-1111-4111-8111-111111111111';
const _childId = '22222222-2222-4222-8222-222222222222';
const _originId = '33333333-3333-4333-8333-333333333333';

Future<PlanGoal> _create(
  PlanRepositoryImpl repository,
  String title, {
  String? parentGoalId,
}) {
  return repository.createGoal(
    PlanGoalSaveData(
      parentGoalId: parentGoalId,
      title: title,
      goalLevel: PlanGoalLevel.year,
    ),
  );
}

PlanSyncPayload _payload({required String title, String? parentId}) {
  return PlanSyncPayload(
    parentGoalId: parentId,
    title: title,
    description: null,
    goalLevel: PlanGoalLevel.year,
    status: PlanGoalStatus.notStarted,
    startDate: '2026-01-01',
    targetDate: '2026-12-31',
    completedAt: null,
    archivedAt: null,
    sortOrder: 0,
    createdAt: 10,
  );
}

SyncChange _remoteChange({
  required String id,
  required String title,
  required int version,
  String? parentId,
}) {
  return SyncChange(
    entityType: SyncEntityType.plan,
    operation: SyncOperation.upsert,
    recordId: id,
    payload: _payload(title: title, parentId: parentId),
    updatedAt: version * 100,
    deletedAt: null,
    originDeviceId: _originId,
    serverVersion: version,
  );
}
