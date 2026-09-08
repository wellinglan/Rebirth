import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/features/health/domain/health_sync_payload.dart';
import 'package:rebirth/features/sync/data/sync_conflict_providers.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/today/domain/today_sync_payload.dart';

void main() {
  test(
    'Today reconciliation snapshot retains scale and descriptions',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final bootstrap = await database.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      const recordId = '11111111-1111-4111-8111-111111111111';
      await database
          .into(database.todayRecords)
          .insert(
            TodayRecordsCompanion.insert(
              id: const Value(recordId),
              userId: bootstrap.activeUserId,
              recordDate: '2026-09-09',
              timezoneOffsetMinutes: 480,
              moodScore: const Value(8),
              wellbeingScoreScale: const Value(10),
              moodDescription: const Value('心情平稳'),
              energyScore: const Value(6),
              energyDescription: const Value('午后稍累'),
              researchMinutes: const Value(0),
              researchDescription: const Value('完成资料整理'),
              learningMinutes: const Value(null),
              learningDescription: const Value('准备明天继续'),
            ),
          );

      final snapshot = await loadCurrentSyncSnapshot(
        database,
        SyncEntityType.today,
        bootstrap.activeUserId,
        recordId,
      );
      final payload = snapshot!.payload! as TodaySyncPayload;

      expect(payload.wellbeingScoreScale, 10);
      expect(payload.moodDescription, '心情平稳');
      expect(payload.energyDescription, '午后稍累');
      expect(payload.researchMinutes, 0);
      expect(payload.researchDescription, '完成资料整理');
      expect(payload.learningMinutes, isNull);
      expect(payload.learningDescription, '准备明天继续');
    },
  );

  test(
    'Health reconciliation snapshot retains all metric narratives',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final bootstrap = await database.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      const recordId = '22222222-2222-4222-8222-222222222222';
      await database
          .into(database.healthRecords)
          .insert(
            HealthRecordsCompanion.insert(
              id: const Value(recordId),
              userId: bootstrap.activeUserId,
              recordDate: '2026-09-09',
              timezoneOffsetMinutes: 480,
              sleepDurationMinutes: const Value(0),
              sleepDescription: const Value('夜间醒来一次'),
              weightKg: const Value(65.5),
              weightDescription: const Value('晨起测量'),
              waterIntakeMl: const Value(null),
              waterDescription: const Value('尚未记录饮水量'),
              exerciseType: const Value('walking'),
              exerciseDurationMinutes: const Value(30),
              exerciseDescription: const Value('轻松步行'),
              physicalStateScore: const Value(7),
              physicalStateScoreScale: const Value(10),
              physicalStateDescription: const Value('恢复良好'),
            ),
          );

      final snapshot = await loadCurrentSyncSnapshot(
        database,
        SyncEntityType.health,
        bootstrap.activeUserId,
        recordId,
      );
      final payload = snapshot!.payload! as HealthSyncPayload;

      expect(payload.physicalStateScoreScale, 10);
      expect(payload.sleepDurationMinutes, 0);
      expect(payload.sleepDescription, '夜间醒来一次');
      expect(payload.weightDescription, '晨起测量');
      expect(payload.waterIntakeMl, isNull);
      expect(payload.waterDescription, '尚未记录饮水量');
      expect(payload.exerciseDescription, '轻松步行');
      expect(payload.physicalStateDescription, '恢复良好');
    },
  );
}
