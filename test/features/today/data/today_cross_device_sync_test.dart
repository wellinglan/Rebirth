import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/today/data/today_repository_impl.dart';
import 'package:rebirth/features/today/data/today_sync_adapter.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_save_data.dart';

void main() {
  test(
    'Windows and Android exchange one Today identity without Health',
    () async {
      final windowsDb = AppDatabase.forTesting(NativeDatabase.memory());
      final androidDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async {
        await windowsDb.close();
        await androidDb.close();
      });
      final clock = DateTimeService(now: () => DateTime(2026, 7, 28, 9));
      final windowsRepository = TodayRepositoryImpl(
        database: windowsDb,
        dateTimeService: clock,
      );
      final androidRepository = TodayRepositoryImpl(
        database: androidDb,
        dateTimeService: clock,
      );
      final windowsAdapter = TodaySyncAdapter(windowsDb);
      final androidAdapter = TodaySyncAdapter(androidDb);

      final windowsToday = await windowsRepository.saveToday(
        TodaySaveData(
          priorities: const [
            TodayPriority(text: 'Ship sync', completed: false),
          ],
          moodScore: 4,
          energyScore: 3,
          researchMinutes: null,
          learningMinutes: 0,
          dailyNote: 'Created on Windows',
          health: const TodayHealthInput(
            sleepDurationMinutes: 450,
            waterIntakeMl: 1600,
          ),
        ),
      );
      final windowsPush = (await windowsAdapter.collectPending()).single;
      final cloudV1 = _asCloudChange(windowsPush, serverVersion: 1);
      await windowsAdapter.acknowledgePush(
        submitted: [windowsPush],
        accepted: [
          SyncAcknowledgement(
            entityType: SyncEntityType.today,
            recordId: windowsPush.recordId,
            serverVersion: 1,
          ),
        ],
        conflicts: const [],
        syncedAt: 100,
      );

      final androidPlaceholder = await androidRepository.getToday();
      expect(androidPlaceholder.id, isNot(windowsToday.id));
      await androidAdapter.applyRemoteChanges(
        changes: [cloudV1],
        syncedAt: 110,
      );
      final androidToday = await androidRepository.getToday();

      expect(androidToday.id, windowsToday.id);
      expect(androidToday.priorities.first.text, 'Ship sync');
      expect(androidToday.researchMinutes, isNull);
      expect(androidToday.learningMinutes, 0);
      expect(androidToday.dailyNote, 'Created on Windows');
      expect(androidToday.health, isNull);

      await androidRepository.saveToday(
        TodaySaveData(
          priorities: const [TodayPriority(text: 'Ship sync', completed: true)],
          moodScore: 5,
          energyScore: 3,
          researchMinutes: 90,
          learningMinutes: 0,
          dailyNote: 'Completed on Android',
          health: const TodayHealthInput(
            exerciseDurationMinutes: 30,
            note: 'Android-only health',
          ),
        ),
      );
      final androidPush = (await androidAdapter.collectPending()).single;
      expect(androidPush.recordId, windowsToday.id);
      final cloudV2 = _asCloudChange(androidPush, serverVersion: 2);
      await androidAdapter.acknowledgePush(
        submitted: [androidPush],
        accepted: [
          SyncAcknowledgement(
            entityType: SyncEntityType.today,
            recordId: androidPush.recordId,
            serverVersion: 2,
          ),
        ],
        conflicts: const [],
        syncedAt: 120,
      );

      await windowsAdapter.applyRemoteChanges(
        changes: [cloudV2],
        syncedAt: 130,
      );
      final windowsUpdated = await windowsRepository.getToday();
      final androidUpdated = await androidRepository.getToday();

      expect(windowsUpdated.id, androidUpdated.id);
      expect(windowsUpdated.priorities.first.completed, isTrue);
      expect(windowsUpdated.moodScore, 5);
      expect(windowsUpdated.researchMinutes, 90);
      expect(windowsUpdated.learningMinutes, 0);
      expect(windowsUpdated.dailyNote, 'Completed on Android');
      expect(windowsUpdated.health?.sleepDurationMinutes, 450);
      expect(windowsUpdated.health?.waterIntakeMl, 1600);
      expect(windowsUpdated.health?.exerciseDurationMinutes, isNull);
      expect(androidUpdated.health?.exerciseDurationMinutes, 30);
      expect(androidUpdated.health?.note, 'Android-only health');
      expect(androidUpdated.health?.sleepDurationMinutes, isNull);
    },
  );

  test('null and zero survive a cross-device round trip', () async {
    final sourceDb = AppDatabase.forTesting(NativeDatabase.memory());
    final targetDb = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async {
      await sourceDb.close();
      await targetDb.close();
    });
    final clock = DateTimeService(now: () => DateTime(2026, 7, 28));
    final sourceRepository = TodayRepositoryImpl(
      database: sourceDb,
      dateTimeService: clock,
    );
    final targetRepository = TodayRepositoryImpl(
      database: targetDb,
      dateTimeService: clock,
    );
    final sourceAdapter = TodaySyncAdapter(sourceDb);
    final targetAdapter = TodaySyncAdapter(targetDb);

    await sourceRepository.saveToday(
      TodaySaveData(researchMinutes: null, learningMinutes: 0),
    );
    final pending = (await sourceAdapter.collectPending()).single;
    await targetAdapter.applyRemoteChanges(
      changes: [_asCloudChange(pending, serverVersion: 1)],
      syncedAt: 100,
    );
    final target = await targetRepository.getToday();

    expect(target.researchMinutes, isNull);
    expect(target.learningMinutes, 0);
  });
}

SyncChange _asCloudChange(SyncPushItem item, {required int serverVersion}) {
  return SyncChange(
    entityType: SyncEntityType.today,
    operation: item.operation,
    recordId: item.recordId,
    payload: item.payload,
    updatedAt: item.updatedAt,
    deletedAt: item.deletedAt,
    originDeviceId: item.originDeviceId,
    serverVersion: serverVersion,
  );
}
