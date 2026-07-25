import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/plan/data/plan_repository_impl.dart';
import 'package:rebirth/features/plan/data/plan_sync_adapter.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_goal_save_data.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

void main() {
  test(
    'Windows and Android round trip preserves the complete Plan subtree',
    () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(() {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
      });
      final windowsDatabase = AppDatabase.forTesting(NativeDatabase.memory());
      final androidDatabase = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(windowsDatabase.close);
      addTearDown(androidDatabase.close);
      final windowsRepository = _repository(windowsDatabase, 8);
      final androidRepository = _repository(androidDatabase, 9);
      final windowsAdapter = PlanSyncAdapter(windowsDatabase);
      final androidAdapter = PlanSyncAdapter(androidDatabase);
      final cloud = _FakePlanCloud();

      final root = await windowsRepository.createGoal(
        PlanGoalSaveData(
          title: 'Cross-device root',
          goalLevel: PlanGoalLevel.year,
        ),
      );
      final child = await windowsRepository.createGoal(
        PlanGoalSaveData(
          parentGoalId: root.id,
          title: 'Cross-device child',
          goalLevel: PlanGoalLevel.month,
        ),
      );
      await cloud.push(windowsAdapter);
      await cloud.pull(androidAdapter);

      final androidRoot = await androidRepository.getById(root.id);
      final androidChild = await androidRepository.getById(child.id);
      expect(androidRoot?.id, root.id);
      expect(androidChild?.id, child.id);
      expect(androidChild?.parentGoalId, root.id);

      await androidRepository.updateCompletion(id: child.id, completed: true);
      await cloud.push(androidAdapter);
      await cloud.pull(windowsAdapter);
      expect(
        (await windowsRepository.getById(child.id))?.status,
        PlanGoalStatus.completed,
      );

      await windowsRepository.archiveGoal(root.id);
      await cloud.push(windowsAdapter);
      await cloud.pull(androidAdapter);
      expect(
        (await androidRepository.listRootGoals(
          includeArchived: true,
        )).single.archivedAt,
        isNotNull,
      );
      expect(
        (await androidRepository.listChildren(
          root.id,
          includeArchived: true,
        )).single.archivedAt,
        isNotNull,
      );

      await windowsRepository.restoreGoal(root.id);
      await cloud.push(windowsAdapter);
      await cloud.pull(androidAdapter);
      expect((await androidRepository.getById(root.id))?.archivedAt, isNull);
      expect((await androidRepository.getById(child.id))?.archivedAt, isNull);

      await windowsRepository.softDelete(root.id);
      await cloud.push(windowsAdapter);
      await cloud.pull(androidAdapter);
      expect(await androidRepository.getById(root.id), isNull);
      expect(await androidRepository.getById(child.id), isNull);
      final androidRows = await androidDatabase
          .select(androidDatabase.goals)
          .get();
      expect(androidRows, hasLength(2));
      expect(androidRows.every((row) => row.deletedAt != null), isTrue);
      expect(androidRows.every((row) => row.syncStatus == 'synced'), isTrue);
    },
  );
}

PlanRepositoryImpl _repository(AppDatabase database, int hour) {
  return PlanRepositoryImpl(
    database: database,
    dateTimeService: DateTimeService(
      now: () => DateTime.utc(2026, 7, 21, hour),
    ),
  );
}

final class _FakePlanCloud {
  final Map<String, SyncChange> _records = {};
  int _version = 0;

  Future<void> push(PlanSyncAdapter adapter) async {
    final submitted = await adapter.collectPending();
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
    await adapter.acknowledgePush(
      submitted: submitted,
      accepted: accepted,
      conflicts: const [],
      syncedAt: 2_000 + _version,
    );
  }

  Future<void> pull(PlanSyncAdapter adapter) {
    return adapter
        .applyRemoteChanges(
          changes: _records.values.toList(growable: false),
          syncedAt: 3_000 + _version,
        )
        .then((_) {});
  }
}
