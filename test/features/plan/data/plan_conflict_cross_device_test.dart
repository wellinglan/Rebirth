import 'package:drift/drift.dart' hide isNotNull, isNull;
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
import 'package:rebirth/features/sync/data/sync_conflict_repository_impl.dart';
import 'package:rebirth/features/sync/domain/sync_conflict.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

void main() {
  test(
    'cross-device keep-local converges both devices and resolves conflict',
    () async {
      final harness = await _Harness.create();
      addTearDown(harness.close);
      final goal = await harness.seed();

      await _edit(harness.windowsRepository, goal, 'Windows newer');
      await _edit(harness.androidRepository, goal, 'Android kept');
      await harness.cloud.push(harness.windowsAdapter);
      final stale = await harness.cloud.push(harness.androidAdapter);
      expect(stale.status, SyncEntityStatus.conflict);

      await harness.cloud.pull(harness.androidAdapter);
      var conflict = (await harness.androidConflicts.listActiveConflicts(
        harness.androidScope,
      )).single;
      expect(
        conflict.resolutionStatus,
        SyncConflictResolutionStatus.unresolved,
      );
      expect(
        (await harness.androidRepository.getById(goal.id))?.title,
        'Android kept',
      );

      await harness.androidResolution.requestKeepLocal(
        scope: harness.androidScope,
        conflictId: conflict.id,
      );
      await harness.cloud.push(harness.androidAdapter);
      conflict = await harness.androidConflicts.getConflict(
        harness.androidScope,
        conflict.id,
      );
      await harness.cloud.pull(harness.windowsAdapter);

      expect(
        conflict.resolutionStatus,
        SyncConflictResolutionStatus.resolvedKeepLocal,
      );
      expect(
        (await harness.windowsRepository.getById(goal.id))?.title,
        'Android kept',
      );
      expect(
        (await harness.androidRepository.getById(goal.id))?.title,
        'Android kept',
      );
    },
  );

  test('cross-device adopt-remote discards only after explicit pull', () async {
    final harness = await _Harness.create();
    addTearDown(harness.close);
    final goal = await harness.seed();

    await _edit(harness.windowsRepository, goal, 'Windows server version');
    await _edit(harness.androidRepository, goal, 'Android conflict');
    await harness.cloud.push(harness.windowsAdapter);
    await harness.cloud.push(harness.androidAdapter);
    await harness.cloud.pull(harness.androidAdapter);
    final conflict = (await harness.androidConflicts.listActiveConflicts(
      harness.androidScope,
    )).single;

    await harness.androidResolution.requestAdoptRemote(
      scope: harness.androidScope,
      conflictId: conflict.id,
    );
    expect(
      (await harness.androidRepository.getById(goal.id))?.title,
      'Android conflict',
    );
    await harness.cloud.pull(harness.androidAdapter);
    final resolved = await harness.androidConflicts.getConflict(
      harness.androidScope,
      conflict.id,
    );

    expect(
      resolved.resolutionStatus,
      SyncConflictResolutionStatus.resolvedAdoptRemote,
    );
    expect(
      (await harness.androidRepository.getById(goal.id))?.title,
      'Windows server version',
    );
  });

  test(
    'remote tombstone conflict can be adopted without orphan data',
    () async {
      final harness = await _Harness.create();
      addTearDown(harness.close);
      final goal = await harness.seed();

      await _edit(harness.androidRepository, goal, 'Android pending');
      await harness.windowsRepository.softDelete(goal.id);
      await harness.cloud.push(harness.windowsAdapter);
      await harness.cloud.push(harness.androidAdapter);
      await harness.cloud.pull(harness.androidAdapter);
      final conflict = (await harness.androidConflicts.listActiveConflicts(
        harness.androidScope,
      )).single;
      expect(conflict.remoteOperation, SyncConflictOperation.delete);

      await harness.androidResolution.requestAdoptRemote(
        scope: harness.androidScope,
        conflictId: conflict.id,
      );
      await harness.cloud.pull(harness.androidAdapter);
      final row = await (harness.androidDatabase.select(
        harness.androidDatabase.goals,
      )..where((item) => item.id.equals(goal.id))).getSingle();

      expect(row.deletedAt, isNotNull);
      expect(row.syncStatus, 'synced');
      expect(
        (await harness.androidConflicts.getConflict(
          harness.androidScope,
          conflict.id,
        )).resolutionStatus,
        SyncConflictResolutionStatus.resolvedAdoptRemote,
      );
    },
  );

  test('local tombstone conflict can be kept and uploaded', () async {
    final harness = await _Harness.create();
    addTearDown(harness.close);
    final goal = await harness.seed();

    await harness.androidRepository.softDelete(goal.id);
    await _edit(harness.windowsRepository, goal, 'Windows remote edit');
    await harness.cloud.push(harness.windowsAdapter);
    await harness.cloud.push(harness.androidAdapter);
    await harness.cloud.pull(harness.androidAdapter);
    final conflict = (await harness.androidConflicts.listActiveConflicts(
      harness.androidScope,
    )).single;

    await harness.androidResolution.requestKeepLocal(
      scope: harness.androidScope,
      conflictId: conflict.id,
    );
    final pending = await harness.androidAdapter.collectPending();
    expect(pending.single.operation, SyncOperation.delete);
    await harness.cloud.push(harness.androidAdapter);
    await harness.cloud.pull(harness.windowsAdapter);

    expect(
      (await harness.androidConflicts.getConflict(
        harness.androidScope,
        conflict.id,
      )).resolutionStatus,
      SyncConflictResolutionStatus.resolvedKeepLocal,
    );
    expect(await harness.windowsRepository.getById(goal.id), isNull);
  });
}

final class _Harness {
  _Harness._({
    required this.windowsDatabase,
    required this.androidDatabase,
    required this.windowsRepository,
    required this.androidRepository,
    required this.windowsAdapter,
    required this.androidAdapter,
    required this.androidConflicts,
    required this.androidScope,
    required this.androidResolution,
    required this.cloud,
  });

  final AppDatabase windowsDatabase;
  final AppDatabase androidDatabase;
  final PlanRepositoryImpl windowsRepository;
  final PlanRepositoryImpl androidRepository;
  final PlanSyncAdapter windowsAdapter;
  final PlanSyncAdapter androidAdapter;
  final SyncConflictRepositoryImpl androidConflicts;
  final SyncConflictScope androidScope;
  final PlanConflictResolutionServiceImpl androidResolution;
  final _StrictFakeCloud cloud;

  static Future<_Harness> create() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final windowsDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    final androidDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    final windowsBootstrap = await windowsDatabase.bootstrapDao.bootstrap(createUnboundProfile: true);
    final androidBootstrap = await androidDatabase.bootstrapDao.bootstrap(createUnboundProfile: true);
    const endpoint = 'http://server-a:8000';
    const cloudUser = 'cloud-user-a';
    final windowsScope = SyncConflictScope(
      localUserId: windowsBootstrap.activeUserId,
      endpointKey: endpoint,
      cloudUserId: cloudUser,
    );
    final androidScope = SyncConflictScope(
      localUserId: androidBootstrap.activeUserId,
      endpointKey: endpoint,
      cloudUserId: cloudUser,
    );
    final clock = DateTimeService(now: () => DateTime.utc(2026, 7, 23, 8));
    final windowsConflicts = SyncConflictRepositoryImpl(
      windowsDatabase,
      payloadCodecs: const [PlanSyncPayloadCodec()],
    );
    final androidConflicts = SyncConflictRepositoryImpl(
      androidDatabase,
      payloadCodecs: const [PlanSyncPayloadCodec()],
    );
    return _Harness._(
      windowsDatabase: windowsDatabase,
      androidDatabase: androidDatabase,
      windowsRepository: PlanRepositoryImpl(
        database: windowsDatabase,
        dateTimeService: clock,
      ),
      androidRepository: PlanRepositoryImpl(
        database: androidDatabase,
        dateTimeService: clock,
      ),
      windowsAdapter: PlanSyncAdapter(
        windowsDatabase,
        windowsConflicts,
        () async => windowsScope,
        clock,
      ),
      androidAdapter: PlanSyncAdapter(
        androidDatabase,
        androidConflicts,
        () async => androidScope,
        clock,
      ),
      androidConflicts: androidConflicts,
      androidScope: androidScope,
      androidResolution: PlanConflictResolutionServiceImpl(
        androidDatabase,
        androidConflicts,
        clock,
      ),
      cloud: _StrictFakeCloud(),
    );
  }

  Future<PlanGoal> seed() async {
    final goal = await windowsRepository.createGoal(
      PlanGoalSaveData(title: 'Shared goal', goalLevel: PlanGoalLevel.year),
    );
    await cloud.push(windowsAdapter);
    await cloud.pull(androidAdapter);
    return goal;
  }

  Future<void> close() async {
    await windowsDatabase.close();
    await androidDatabase.close();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
  }
}

final class _StrictFakeCloud {
  final Map<String, SyncChange> _records = {};
  int _version = 0;

  Future<SyncEntityResult> push(PlanSyncAdapter adapter) async {
    final submitted = await adapter.collectPending();
    if (submitted.isEmpty) {
      return adapter.acknowledgePush(
        submitted: const [],
        accepted: const [],
        conflicts: const [],
        syncedAt: 10_000 + _version,
      );
    }
    final stale = submitted
        .where((item) {
          final current = _records[item.recordId];
          return item.clientVersion != (current?.serverVersion ?? 0);
        })
        .toList(growable: false);
    if (stale.isNotEmpty) {
      final staleIds = stale.map((item) => item.recordId).toSet();
      return adapter.acknowledgePush(
        submitted: submitted,
        accepted: const [],
        conflicts: [
          for (final item in submitted)
            SyncConflict(
              tableName: SyncEntityType.plan.wireName,
              recordId: item.recordId,
              serverVersion: _records[item.recordId]?.serverVersion ?? 0,
              reason: staleIds.contains(item.recordId)
                  ? 'stale_client'
                  : 'request_conflict',
            ),
        ],
        syncedAt: 10_000 + _version,
      );
    }

    final accepted = <SyncAcknowledgement>[];
    for (final item in submitted) {
      _version += 1;
      _records[item.recordId] = SyncChange(
        entityType: SyncEntityType.plan,
        operation: item.operation,
        recordId: item.recordId,
        payload: item.payload,
        updatedAt: item.updatedAt,
        deletedAt: item.deletedAt,
        originDeviceId: item.originDeviceId,
        serverVersion: _version,
      );
      accepted.add(
        SyncAcknowledgement(
          entityType: SyncEntityType.plan,
          recordId: item.recordId,
          serverVersion: _version,
        ),
      );
    }
    return adapter.acknowledgePush(
      submitted: submitted,
      accepted: accepted,
      conflicts: const [],
      syncedAt: 10_000 + _version,
    );
  }

  Future<SyncEntityResult> pull(PlanSyncAdapter adapter) {
    return adapter.applyRemoteChanges(
      changes: _records.values.toList(growable: false),
      syncedAt: 20_000 + _version,
    );
  }
}

Future<void> _edit(PlanRepositoryImpl repository, PlanGoal seed, String title) {
  return repository
      .updateGoal(
        id: seed.id,
        data: PlanGoalSaveData(
          parentGoalId: seed.parentGoalId,
          title: title,
          description: seed.description,
          goalLevel: seed.goalLevel,
          status: seed.status,
          startDate: seed.startDate,
          targetDate: seed.targetDate,
          sortOrder: seed.sortOrder,
        ),
      )
      .then((_) {});
}
