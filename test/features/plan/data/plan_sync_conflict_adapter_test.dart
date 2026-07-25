import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/plan/data/plan_conflict_resolution_service_impl.dart';
import 'package:rebirth/features/plan/data/plan_repository_impl.dart';
import 'package:rebirth/features/plan/data/plan_sync_adapter.dart';
import 'package:rebirth/features/plan/data/plan_sync_payload_codec.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_goal_save_data.dart';
import 'package:rebirth/features/plan/domain/plan_sync_payload.dart';
import 'package:rebirth/features/sync/data/sync_conflict_repository_impl.dart';
import 'package:rebirth/features/sync/domain/sync_conflict.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

void main() {
  late AppDatabase database;
  late PlanRepositoryImpl planRepository;
  late SyncConflictRepositoryImpl conflictRepository;
  late SyncConflictScope scope;
  late PlanSyncAdapter adapter;
  late DateTime now;
  late Future<PlanGoal> Function() createAwaitingPushConflict;
  late Future<PlanGoal> Function() createHydratedConflict;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final bootstrap = await database.bootstrapDao.bootstrap();
    scope = SyncConflictScope(
      localUserId: bootstrap.activeUserId,
      endpointKey: 'http://server-a:8000',
      cloudUserId: 'cloud-user-a',
    );
    now = DateTime.utc(2026, 7, 22, 8);
    final clock = DateTimeService(now: () => now);
    planRepository = PlanRepositoryImpl(
      database: database,
      dateTimeService: clock,
    );
    conflictRepository = SyncConflictRepositoryImpl(
      database,
      payloadCodecs: const [PlanSyncPayloadCodec()],
    );
    adapter = PlanSyncAdapter(
      database,
      conflictRepository,
      () async => scope,
      clock,
    );
    createAwaitingPushConflict = () async {
      final goal = await _syncedGoal(planRepository, database, version: 5);
      await _editGoal(planRepository, goal, title: 'Local pending');
      final submitted = await adapter.collectPending();
      await adapter.acknowledgePush(
        submitted: submitted,
        accepted: const [],
        conflicts: [
          SyncConflict(
            tableName: SyncEntityType.plan.wireName,
            recordId: goal.id,
            serverVersion: 6,
            reason: 'stale_client',
          ),
        ],
        syncedAt: 1_000,
      );
      return goal;
    };
    createHydratedConflict = () async {
      final goal = await createAwaitingPushConflict();
      await adapter.applyRemoteChanges(
        changes: [_upsert(goal.id, title: 'Remote v6', version: 6)],
        syncedAt: 1_100,
      );
      return goal;
    };
  });

  tearDown(() => database.close());

  test(
    'pull conflict persists both snapshots and blocks the whole batch',
    () async {
      final goal = await _syncedGoal(planRepository, database, version: 5);
      await _editGoal(planRepository, goal, title: 'Local pending');

      final result = await adapter.applyRemoteChanges(
        changes: [
          _upsert(goal.id, title: 'Remote v6', version: 6),
          _upsert(_unrelatedId, title: 'Must not apply', version: 7),
        ],
        syncedAt: 1_000,
      );
      final local = await _goal(database, goal.id);
      final conflicts = await conflictRepository.listActiveConflicts(scope);

      expect(result.status, SyncEntityStatus.conflict);
      expect(local.title, 'Local pending');
      expect(local.syncStatus, 'conflict');
      expect(await _goalOrNull(database, _unrelatedId), isNull);
      expect(conflicts, hasLength(1));
      expect(
        (conflicts.single.localSnapshot.payload as PlanSyncPayload).title,
        'Local pending',
      );
      expect(
        (conflicts.single.remoteSnapshot.payload as PlanSyncPayload).title,
        'Remote v6',
      );
    },
  );

  test(
    'pull replay is idempotent and only a higher version replaces remote',
    () async {
      final goal = await _syncedGoal(planRepository, database, version: 5);
      await _editGoal(planRepository, goal, title: 'Local snapshot');
      await adapter.applyRemoteChanges(
        changes: [_upsert(goal.id, title: 'Remote v6', version: 6)],
        syncedAt: 1_000,
      );
      final first = (await conflictRepository.listActiveConflicts(
        scope,
      )).single;

      await (database.update(
        database.goals,
      )..where((row) => row.id.equals(goal.id))).write(
        const GoalsCompanion(
          title: Value('Edited after conflict'),
          updatedAt: Value(1_050),
          syncStatus: Value('pending'),
        ),
      );
      await adapter.applyRemoteChanges(
        changes: [_upsert(goal.id, title: 'Remote v6 replay', version: 6)],
        syncedAt: 1_100,
      );
      await adapter.applyRemoteChanges(
        changes: [_upsert(goal.id, title: 'Remote v8', version: 8)],
        syncedAt: 1_200,
      );
      await adapter.applyRemoteChanges(
        changes: [_upsert(goal.id, title: 'Remote v7 old', version: 7)],
        syncedAt: 1_300,
      );
      final replayed = (await conflictRepository.listActiveConflicts(
        scope,
      )).single;

      expect(replayed.id, first.id);
      expect(
        (replayed.localSnapshot.payload as PlanSyncPayload).title,
        'Local snapshot',
      );
      expect(replayed.remoteSnapshot.serverVersion, 8);
      expect(
        (replayed.remoteSnapshot.payload as PlanSyncPayload).title,
        'Remote v8',
      );
      expect(replayed.lastSeenAt, 1_300);
    },
  );

  test(
    'stale push persists awaiting snapshot without fake request conflicts',
    () async {
      final stale = await _syncedGoal(planRepository, database, version: 5);
      final collateral = await _syncedGoal(
        planRepository,
        database,
        title: 'Collateral',
        version: 2,
      );
      await _editGoal(planRepository, stale, title: 'Stale local');
      await _editGoal(planRepository, collateral, title: 'Blocked local');
      final submitted = await adapter.collectPending();

      final result = await adapter.acknowledgePush(
        submitted: submitted,
        accepted: const [],
        conflicts: [
          SyncConflict(
            tableName: SyncEntityType.plan.wireName,
            recordId: stale.id,
            serverVersion: 6,
            reason: 'stale_client',
          ),
          SyncConflict(
            tableName: SyncEntityType.plan.wireName,
            recordId: collateral.id,
            serverVersion: 2,
            reason: 'request_conflict',
          ),
        ],
        syncedAt: 1_000,
      );
      final conflicts = await conflictRepository.listActiveConflicts(scope);

      expect(result.conflictCount, 1);
      expect(conflicts, hasLength(1));
      expect(conflicts.single.recordId, stale.id);
      expect(
        conflicts.single.resolutionStatus,
        SyncConflictResolutionStatus.awaitingRemoteSnapshot,
      );
      expect(
        conflicts.single.remoteOperation,
        SyncConflictOperation.unknownPendingPull,
      );
      expect(conflicts.single.remoteSnapshot.payload, isNull);
      expect((await _goal(database, collateral.id)).syncStatus, 'pending');

      await adapter.acknowledgePush(
        submitted: submitted,
        accepted: const [],
        conflicts: [
          SyncConflict(
            tableName: SyncEntityType.plan.wireName,
            recordId: stale.id,
            serverVersion: 6,
            reason: 'stale_client',
          ),
          SyncConflict(
            tableName: SyncEntityType.plan.wireName,
            recordId: collateral.id,
            serverVersion: 2,
            reason: 'request_conflict',
          ),
        ],
        syncedAt: 1_100,
      );
      expect(await conflictRepository.listActiveConflicts(scope), hasLength(1));
    },
  );

  test(
    'pull hydrates an awaiting push conflict without applying remote',
    () async {
      final goal = await createAwaitingPushConflict();

      final result = await adapter.applyRemoteChanges(
        changes: [_upsert(goal.id, title: 'Remote hydrated', version: 6)],
        syncedAt: 1_100,
      );
      final conflict = (await conflictRepository.listActiveConflicts(
        scope,
      )).single;

      expect(result.status, SyncEntityStatus.conflict);
      expect((await _goal(database, goal.id)).title, 'Local pending');
      expect(
        conflict.resolutionStatus,
        SyncConflictResolutionStatus.unresolved,
      );
      expect(
        (conflict.remoteSnapshot.payload as PlanSyncPayload).title,
        'Remote hydrated',
      );
    },
  );

  test(
    'adopt remote keeps local until pull then applies latest upsert',
    () async {
      final goal = await createHydratedConflict();
      final conflict = (await conflictRepository.listActiveConflicts(
        scope,
      )).single;
      final resolution = PlanConflictResolutionServiceImpl(
        database,
        conflictRepository,
        DateTimeService(now: () => now),
      );

      await resolution.requestAdoptRemote(
        scope: scope,
        conflictId: conflict.id,
      );
      expect((await _goal(database, goal.id)).title, 'Local pending');
      expect(
        (await conflictRepository.getConflict(
          scope,
          conflict.id,
        )).resolutionStatus,
        SyncConflictResolutionStatus.adoptRemoteRequested,
      );

      final result = await adapter.applyRemoteChanges(
        changes: [_upsert(goal.id, title: 'Remote latest', version: 7)],
        syncedAt: 1_200,
      );
      final applied = await _goal(database, goal.id);
      final resolved = await conflictRepository.getConflict(scope, conflict.id);

      expect(result.status, SyncEntityStatus.succeeded);
      expect(applied.title, 'Remote latest');
      expect(applied.syncStatus, 'synced');
      expect(applied.serverVersion, 7);
      expect(resolved.remoteSnapshot.serverVersion, 7);
      expect(
        resolved.resolutionStatus,
        SyncConflictResolutionStatus.resolvedAdoptRemote,
      );
      expect(resolved.resolvedAt, 1_200);
    },
  );

  test(
    'adopt remote tombstone soft deletes and resolves the conflict',
    () async {
      final goal = await createHydratedConflict();
      final conflict = (await conflictRepository.listActiveConflicts(
        scope,
      )).single;
      final resolution = PlanConflictResolutionServiceImpl(
        database,
        conflictRepository,
      );
      await resolution.requestAdoptRemote(
        scope: scope,
        conflictId: conflict.id,
      );

      await adapter.applyRemoteChanges(
        changes: [_delete(goal.id, version: 7)],
        syncedAt: 1_200,
      );
      final deleted = await _goal(database, goal.id);
      final resolved = await conflictRepository.getConflict(scope, conflict.id);

      expect(deleted.deletedAt, 700);
      expect(deleted.syncStatus, 'synced');
      expect(
        resolved.resolutionStatus,
        SyncConflictResolutionStatus.resolvedAdoptRemote,
      );
    },
  );

  test(
    'keep local uses current content and resolves only after acknowledgement',
    () async {
      final goal = await createHydratedConflict();
      final conflict = (await conflictRepository.listActiveConflicts(
        scope,
      )).single;
      await (database.update(
        database.goals,
      )..where((row) => row.id.equals(goal.id))).write(
        const GoalsCompanion(
          title: Value('Newest local edit'),
          updatedAt: Value(1_150),
          syncStatus: Value('pending'),
        ),
      );
      now = DateTime.fromMillisecondsSinceEpoch(1_300, isUtc: true);
      final resolution = PlanConflictResolutionServiceImpl(
        database,
        conflictRepository,
        DateTimeService(now: () => now),
      );

      await resolution.requestKeepLocal(scope: scope, conflictId: conflict.id);
      final prepared = await _goal(database, goal.id);
      final requested = await conflictRepository.getConflict(
        scope,
        conflict.id,
      );
      final submitted = await adapter.collectPending();

      expect(prepared.title, 'Newest local edit');
      expect(prepared.serverVersion, 6);
      expect(prepared.syncStatus, 'pending');
      expect(prepared.updatedAt, 1_300);
      expect(
        requested.resolutionStatus,
        SyncConflictResolutionStatus.keepLocalRequested,
      );
      expect(
        (submitted.single.payload as PlanSyncPayload).title,
        'Newest local edit',
      );
      expect(submitted.single.clientVersion, 6);

      await adapter.acknowledgePush(
        submitted: submitted,
        accepted: [
          SyncAcknowledgement(
            entityType: SyncEntityType.plan,
            recordId: goal.id,
            serverVersion: 7,
          ),
        ],
        conflicts: const [],
        syncedAt: 1_400,
      );
      final resolved = await conflictRepository.getConflict(scope, conflict.id);
      expect((await _goal(database, goal.id)).serverVersion, 7);
      expect(
        resolved.resolutionStatus,
        SyncConflictResolutionStatus.resolvedKeepLocal,
      );
    },
  );

  test(
    'keep-local request survives failure and a later stale response resets',
    () async {
      final goal = await createHydratedConflict();
      final conflict = (await conflictRepository.listActiveConflicts(
        scope,
      )).single;
      final resolution = PlanConflictResolutionServiceImpl(
        database,
        conflictRepository,
      );
      await resolution.requestKeepLocal(scope: scope, conflictId: conflict.id);

      final restartedRepository = SyncConflictRepositoryImpl(
        database,
        payloadCodecs: const [PlanSyncPayloadCodec()],
      );
      expect(
        (await restartedRepository.getConflict(
          scope,
          conflict.id,
        )).resolutionStatus,
        SyncConflictResolutionStatus.keepLocalRequested,
      );
      final submitted = await adapter.collectPending();
      await adapter.acknowledgePush(
        submitted: submitted,
        accepted: const [],
        conflicts: [
          SyncConflict(
            tableName: SyncEntityType.plan.wireName,
            recordId: goal.id,
            serverVersion: 7,
            reason: 'stale_client',
          ),
        ],
        syncedAt: 1_400,
      );
      final reset = await conflictRepository.getConflict(scope, conflict.id);
      expect(
        reset.resolutionStatus,
        SyncConflictResolutionStatus.awaitingRemoteSnapshot,
      );
      expect(reset.remoteSnapshot.serverVersion, 7);
      expect((await _goal(database, goal.id)).title, 'Local pending');
    },
  );

  test(
    'invalid hierarchy during adopt rolls back goal and requested state',
    () async {
      final parent = await _syncedGoal(
        planRepository,
        database,
        title: 'Parent',
        version: 5,
      );
      final child = await planRepository.createGoal(
        PlanGoalSaveData(
          parentGoalId: parent.id,
          title: 'Child local',
          goalLevel: PlanGoalLevel.month,
        ),
      );
      await (database.update(
        database.goals,
      )..where((row) => row.id.equals(child.id))).write(
        const GoalsCompanion(
          syncStatus: Value('pending'),
          serverVersion: Value(5),
        ),
      );
      final orphan = _upsert(
        child.id,
        title: 'Remote orphan',
        version: 6,
        parentId: _missingParentId,
      );
      await adapter.applyRemoteChanges(changes: [orphan], syncedAt: 1_000);
      final conflict = (await conflictRepository.listActiveConflicts(
        scope,
      )).single;
      await conflictRepository.markAdoptRemoteRequested(scope, conflict.id);

      await expectLater(
        adapter.applyRemoteChanges(changes: [orphan], syncedAt: 1_100),
        throwsA(isA<SyncException>()),
      );
      expect((await _goal(database, child.id)).title, 'Child local');
      expect(
        (await conflictRepository.getConflict(
          scope,
          conflict.id,
        )).resolutionStatus,
        SyncConflictResolutionStatus.adoptRemoteRequested,
      );
    },
  );
}

const _originId = '00000000-0000-4000-8000-000000000081';
const _unrelatedId = '00000000-0000-4000-8000-000000000082';
const _missingParentId = '00000000-0000-4000-8000-000000000083';

Future<PlanGoal> _syncedGoal(
  PlanRepositoryImpl repository,
  AppDatabase database, {
  String title = 'Local',
  required int version,
}) async {
  final goal = await repository.createGoal(
    PlanGoalSaveData(title: title, goalLevel: PlanGoalLevel.year),
  );
  await (database.update(
    database.goals,
  )..where((row) => row.id.equals(goal.id))).write(
    GoalsCompanion(
      syncStatus: const Value('synced'),
      serverVersion: Value(version),
      lastSyncedAt: const Value(500),
    ),
  );
  return goal;
}

Future<void> _editGoal(
  PlanRepositoryImpl repository,
  PlanGoal goal, {
  required String title,
}) {
  return repository
      .updateGoal(
        id: goal.id,
        data: PlanGoalSaveData(
          parentGoalId: goal.parentGoalId,
          title: title,
          description: goal.description,
          goalLevel: goal.goalLevel,
          status: goal.status,
          startDate: goal.startDate,
          targetDate: goal.targetDate,
          sortOrder: goal.sortOrder,
        ),
      )
      .then((_) {});
}

SyncChange _upsert(
  String id, {
  required String title,
  required int version,
  String? parentId,
}) {
  return SyncChange(
    entityType: SyncEntityType.plan,
    operation: SyncOperation.upsert,
    recordId: id,
    payload: PlanSyncPayload(
      parentGoalId: parentId,
      title: title,
      description: null,
      goalLevel: parentId == null ? PlanGoalLevel.year : PlanGoalLevel.month,
      status: PlanGoalStatus.inProgress,
      startDate: '2026-01-01',
      targetDate: '2026-12-31',
      completedAt: null,
      archivedAt: null,
      sortOrder: 0,
      createdAt: 100,
    ),
    updatedAt: version * 100,
    deletedAt: null,
    originDeviceId: _originId,
    serverVersion: version,
  );
}

SyncChange _delete(String id, {required int version}) {
  return SyncChange(
    entityType: SyncEntityType.plan,
    operation: SyncOperation.delete,
    recordId: id,
    payload: null,
    updatedAt: version * 100,
    deletedAt: version * 100,
    originDeviceId: _originId,
    serverVersion: version,
  );
}

Future<Goal> _goal(AppDatabase database, String id) {
  return (database.select(
    database.goals,
  )..where((row) => row.id.equals(id))).getSingle();
}

Future<Goal?> _goalOrNull(AppDatabase database, String id) {
  return (database.select(
    database.goals,
  )..where((row) => row.id.equals(id))).getSingleOrNull();
}
