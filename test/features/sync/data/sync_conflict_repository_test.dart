import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/features/plan/data/plan_sync_payload_codec.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_sync_payload.dart';
import 'package:rebirth/features/sync/data/sync_conflict_repository_impl.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';

void main() {
  late AppDatabase database;
  late SyncConflictRepositoryImpl repository;
  late SyncConflictScope scope;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final bootstrap = await database.bootstrapDao.bootstrap();
    scope = SyncConflictScope(
      localUserId: bootstrap.activeUserId,
      endpointKey: 'http://server-a:8000',
      cloudUserId: 'cloud-user-a',
    );
    repository = SyncConflictRepositoryImpl(
      database,
      payloadCodecs: const [PlanSyncPayloadCodec()],
    );
  });

  tearDown(() => database.close());

  test('creates and restores a pull conflict with typed snapshots', () async {
    final created = await repository.upsertDetectedConflict(
      _detection(scope: scope),
    );
    final restored = await repository.getConflict(scope, created.id);

    expect(restored.entityType, SyncEntityType.plan);
    expect(restored.localSnapshot.payload, isA<PlanSyncPayload>());
    expect(restored.remoteSnapshot.payload, isA<PlanSyncPayload>());
    expect(restored.resolutionStatus, SyncConflictResolutionStatus.unresolved);
  });

  test('same remote version is idempotent and updates last seen', () async {
    final first = await repository.upsertDetectedConflict(
      _detection(scope: scope),
    );
    final replay = await repository.upsertDetectedConflict(
      _detection(scope: scope, detectedAt: 120),
    );

    expect(replay.id, first.id);
    expect(replay.lastSeenAt, 120);
    expect(await repository.listActiveConflicts(scope), hasLength(1));
  });

  test(
    'higher remote version replaces snapshot and lower version does not',
    () async {
      final first = await repository.upsertDetectedConflict(
        _detection(scope: scope),
      );
      final higher = await repository.upsertDetectedConflict(
        _detection(
          scope: scope,
          remoteVersion: 8,
          remoteTitle: 'remote-v8',
          detectedAt: 130,
        ),
      );
      final lower = await repository.upsertDetectedConflict(
        _detection(
          scope: scope,
          remoteVersion: 7,
          remoteTitle: 'remote-v7',
          detectedAt: 140,
        ),
      );

      expect(higher.id, first.id);
      expect(higher.remoteSnapshot.serverVersion, 8);
      expect(
        (lower.remoteSnapshot.payload as PlanSyncPayload).title,
        'remote-v8',
      );
    },
  );

  test('push conflict hydrates from awaiting to unresolved', () async {
    final awaiting = await repository.upsertDetectedConflict(
      _detection(scope: scope, awaiting: true, remoteVersion: 9),
    );
    expect(
      awaiting.resolutionStatus,
      SyncConflictResolutionStatus.awaitingRemoteSnapshot,
    );

    final hydrated = await repository.hydrateRemoteSnapshot(
      scope: scope,
      entityType: SyncEntityType.plan,
      recordId: _recordId,
      operation: SyncConflictOperation.upsert,
      remoteSnapshot: _snapshot(
        title: 'hydrated',
        updatedAt: 150,
        serverVersion: 9,
      ),
      seenAt: 150,
    );
    expect(hydrated.resolutionStatus, SyncConflictResolutionStatus.unresolved);
    expect(
      (hydrated.remoteSnapshot.payload as PlanSyncPayload).title,
      'hydrated',
    );
  });

  test('resolution states preserve history and remove active count', () async {
    final conflict = await repository.upsertDetectedConflict(
      _detection(scope: scope),
    );
    await repository.markAdoptRemoteRequested(scope, conflict.id);
    expect(
      (await repository.getConflict(scope, conflict.id)).resolutionStatus,
      SyncConflictResolutionStatus.adoptRemoteRequested,
    );
    await repository.markResolvedAdoptRemote(
      scope,
      conflict.id,
      resolvedAt: 200,
    );

    expect(await repository.listActiveConflicts(scope), isEmpty);
    expect(
      (await repository.getConflict(scope, conflict.id)).resolutionStatus,
      SyncConflictResolutionStatus.resolvedAdoptRemote,
    );
  });

  test('active count watches repository changes', () async {
    final values = <int>[];
    final subscription = repository
        .watchActiveConflictCount(scope)
        .listen(values.add);
    addTearDown(subscription.cancel);
    await Future<void>.delayed(Duration.zero);
    final conflict = await repository.upsertDetectedConflict(
      _detection(scope: scope),
    );
    await Future<void>.delayed(Duration.zero);
    await repository.markResolvedKeepLocal(scope, conflict.id, resolvedAt: 200);
    await Future<void>.delayed(Duration.zero);

    expect(values, containsAllInOrder([0, 1, 0]));
  });

  test('endpoint cloud user and local user scopes stay isolated', () async {
    await repository.upsertDetectedConflict(_detection(scope: scope));
    final otherEndpoint = SyncConflictScope(
      localUserId: scope.localUserId,
      endpointKey: 'http://server-b:8000',
      cloudUserId: scope.cloudUserId,
    );
    final otherCloudUser = SyncConflictScope(
      localUserId: scope.localUserId,
      endpointKey: scope.endpointKey,
      cloudUserId: 'cloud-user-b',
    );
    final otherLocalUser = SyncConflictScope(
      localUserId: '00000000-0000-4000-8000-000000000077',
      endpointKey: scope.endpointKey,
      cloudUserId: scope.cloudUserId,
    );

    expect(await repository.listActiveConflicts(scope), hasLength(1));
    expect(await repository.listActiveConflicts(otherEndpoint), isEmpty);
    expect(await repository.listActiveConflicts(otherCloudUser), isEmpty);
    expect(await repository.listActiveConflicts(otherLocalUser), isEmpty);
  });

  test(
    'resolved conflict permits a new conflict for the same record',
    () async {
      final first = await repository.upsertDetectedConflict(
        _detection(scope: scope),
      );
      await repository.markResolvedKeepLocal(scope, first.id, resolvedAt: 200);
      final second = await repository.upsertDetectedConflict(
        _detection(scope: scope, remoteVersion: 10, detectedAt: 210),
      );

      expect(second.id, isNot(first.id));
      expect(await database.select(database.syncConflicts).get(), hasLength(2));
    },
  );

  test('superseded conflict remains historical and inactive', () async {
    final conflict = await repository.upsertDetectedConflict(
      _detection(scope: scope),
    );
    await repository.markSuperseded(scope, conflict.id, resolvedAt: 200);

    expect(await repository.listActiveConflicts(scope), isEmpty);
    final historical = await repository.getConflict(scope, conflict.id);
    expect(
      historical.resolutionStatus,
      SyncConflictResolutionStatus.superseded,
    );
    expect(historical.resolvedAt, 200);
  });

  test(
    'canonical payload keeps null keys without sync or identity metadata',
    () async {
      await repository.upsertDetectedConflict(_detection(scope: scope));
      final row = await database.select(database.syncConflicts).getSingle();
      final json = jsonDecode(row.localPayloadJson!) as Map<String, dynamic>;

      expect(json.keys.toList(), [
        'parent_goal_id',
        'title',
        'description',
        'goal_level',
        'status',
        'start_date',
        'target_date',
        'completed_at',
        'archived_at',
        'sort_order',
        'created_at',
      ]);
      expect(json, containsPair('description', null));
      expect(json, isNot(contains('user_id')));
      expect(json, isNot(contains('sync_status')));
      expect(json, isNot(contains('last_synced_at')));
      expect(json, isNot(contains('endpoint')));
      expect(json, isNot(contains('token')));
    },
  );

  test('conflict survives closing and reopening the SQLite database', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
    });
    final directory = await Directory.systemTemp.createTemp(
      'rebirth-sync-conflict-',
    );
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    final file = File('${directory.path}/rebirth.sqlite');
    final firstDatabase = AppDatabase.forTesting(NativeDatabase(file));
    final bootstrap = await firstDatabase.bootstrapDao.bootstrap();
    final diskScope = SyncConflictScope(
      localUserId: bootstrap.activeUserId,
      endpointKey: 'http://server-a:8000',
      cloudUserId: 'cloud-user-a',
    );
    final firstRepository = SyncConflictRepositoryImpl(
      firstDatabase,
      payloadCodecs: const [PlanSyncPayloadCodec()],
    );
    final created = await firstRepository.upsertDetectedConflict(
      _detection(scope: diskScope),
    );
    await firstDatabase.close();

    final reopenedDatabase = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(reopenedDatabase.close);
    final reopenedRepository = SyncConflictRepositoryImpl(
      reopenedDatabase,
      payloadCodecs: const [PlanSyncPayloadCodec()],
    );
    final restored = await reopenedRepository.getConflict(
      diskScope,
      created.id,
    );

    expect(restored.recordId, _recordId);
    expect(restored.remoteSnapshot.serverVersion, 7);
    expect((restored.localSnapshot.payload as PlanSyncPayload).title, 'local');
  });
}

const _recordId = '00000000-0000-4000-8000-000000000091';

SyncConflictDetection _detection({
  required SyncConflictScope scope,
  int detectedAt = 100,
  int remoteVersion = 7,
  String remoteTitle = 'remote',
  bool awaiting = false,
}) {
  return SyncConflictDetection(
    scope: scope,
    entityType: SyncEntityType.plan,
    recordId: _recordId,
    localSnapshot: _snapshot(title: 'local', updatedAt: 90, serverVersion: 6),
    remoteSnapshot: awaiting
        ? SyncConflictSnapshot(
            payload: null,
            updatedAt: null,
            deletedAt: null,
            serverVersion: remoteVersion,
            originDeviceId: null,
          )
        : _snapshot(
            title: remoteTitle,
            updatedAt: detectedAt,
            serverVersion: remoteVersion,
          ),
    remoteOperation: awaiting
        ? SyncConflictOperation.unknownPendingPull
        : SyncConflictOperation.upsert,
    resolutionStatus: awaiting
        ? SyncConflictResolutionStatus.awaitingRemoteSnapshot
        : SyncConflictResolutionStatus.unresolved,
    detectedAt: detectedAt,
  );
}

SyncConflictSnapshot _snapshot({
  required String title,
  required int updatedAt,
  required int serverVersion,
}) {
  return SyncConflictSnapshot(
    payload: PlanSyncPayload(
      parentGoalId: null,
      title: title,
      description: null,
      goalLevel: PlanGoalLevel.month,
      status: PlanGoalStatus.inProgress,
      startDate: '2026-07-01',
      targetDate: '2026-07-31',
      completedAt: null,
      archivedAt: null,
      sortOrder: 0,
      createdAt: 10,
    ),
    updatedAt: updatedAt,
    deletedAt: null,
    serverVersion: serverVersion,
    originDeviceId: '00000000-0000-4000-8000-000000000099',
  );
}
