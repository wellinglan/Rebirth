import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/health/data/health_repository_impl.dart';
import 'package:rebirth/features/health/domain/health_save_data.dart';
import 'package:rebirth/features/today/data/today_repository_impl.dart';
import 'package:rebirth/features/today/domain/today_save_data.dart';
import 'package:uuid/uuid.dart';

void main() {
  const uuid = Uuid();
  late AppDatabase database;
  late DateTime currentTime;
  late HealthRepositoryImpl repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    currentTime = DateTime(2026, 7, 14, 9, 30);
    repository = HealthRepositoryImpl(
      database: database,
      dateTimeService: DateTimeService(now: () => currentTime),
    );
  });

  tearDown(() => database.close());

  test('getToday creates one Health record without creating Today', () async {
    final entry = await repository.getToday();
    final raw = await database.select(database.healthRecords).getSingle();

    expect(entry.recordDate, '2026-07-14');
    expect(entry.todayRecordId, isNull);
    expect(raw.createdAt, currentTime.toUtc().millisecondsSinceEpoch);
    expect(raw.updatedAt, currentTime.toUtc().millisecondsSinceEpoch);
    expect(raw.timezoneOffsetMinutes, currentTime.timeZoneOffset.inMinutes);
    expect(await database.select(database.todayRecords).get(), isEmpty);
    expect((await repository.getToday()).id, entry.id);
    expect(await database.select(database.healthRecords).get(), hasLength(1));
  });

  test('saveForDate creates then updates the same active row', () async {
    final created = await repository.saveForDate(
      HealthSaveData(
        recordDate: '2026-07-14',
        sleepDurationMinutes: 450,
        waterIntakeMl: 1500,
      ),
    );
    currentTime = currentTime.add(const Duration(minutes: 10));
    final updated = await repository.saveForDate(
      HealthSaveData(
        recordDate: '2026-07-14',
        sleepDurationMinutes: 0,
        exerciseDurationMinutes: 30,
        exerciseType: '  跑步  ',
      ),
    );

    expect(updated.id, created.id);
    expect(updated.createdAt, created.createdAt);
    expect(updated.updatedAt, currentTime.toUtc().millisecondsSinceEpoch);
    expect(updated.sleepDurationMinutes, 0);
    expect(updated.waterIntakeMl, isNull);
    expect(updated.exerciseType, '跑步');
    expect(await database.select(database.healthRecords).get(), hasLength(1));
  });

  test('getByDate and inclusive date range are date-descending', () async {
    for (final day in [10, 12, 14]) {
      currentTime = DateTime(2026, 7, day, 9);
      await repository.saveForDate(
        HealthSaveData(
          recordDate: '2026-07-${day.toString().padLeft(2, '0')}',
          waterIntakeMl: day * 100,
        ),
      );
    }

    expect((await repository.getByDate('2026-07-12'))?.waterIntakeMl, 1200);
    final entries = await repository.listByDateRange(
      startDate: '2026-07-11',
      endDate: '2026-07-14',
    );
    expect(entries.map((entry) => entry.recordDate), [
      '2026-07-14',
      '2026-07-12',
    ]);
  });

  test('listRecent ignores empty rows and summary uses requested days', () async {
    await repository.getToday();
    for (final day in [10, 13]) {
      await repository.saveForDate(
        HealthSaveData(
          recordDate: '2026-07-$day',
          sleepDurationMinutes: day == 10 ? 420 : 480,
          exerciseDurationMinutes: 30,
          waterIntakeMl: day == 10 ? 1000 : 2000,
          weightKg: day == 10 ? 66 : 65.5,
        ),
      );
    }

    final recent = await repository.listRecent(days: 7);
    final summary = await repository.getSummary(days: 7);

    expect(recent.map((entry) => entry.recordDate), [
      '2026-07-13',
      '2026-07-10',
    ]);
    expect(summary.days, 7);
    expect(summary.recordsCount, 2);
    expect(summary.averageSleepMinutes, 450);
    expect(summary.totalExerciseMinutes, 60);
    expect(summary.averageWaterIntakeMl, 1500);
    expect(summary.latestWeightKg, 65.5);
  });

  test('queries isolate users and hide soft-deleted rows', () async {
    final own = await repository.saveForDate(
      HealthSaveData(recordDate: '2026-07-14', waterIntakeMl: 1000),
    );
    final bootstrap = await database.bootstrapDao.bootstrap();
    final otherUserId = uuid.v4();
    await database.into(database.userProfiles).insert(
      UserProfilesCompanion.insert(
        id: Value(otherUserId),
        timezoneId: 'Etc/UTC',
        isActive: const Value(false),
      ),
    );
    await database.into(database.healthRecords).insert(
      HealthRecordsCompanion.insert(
        id: Value(uuid.v4()),
        userId: otherUserId,
        recordDate: '2026-07-14',
        timezoneOffsetMinutes: 0,
        waterIntakeMl: const Value(2500),
      ),
    );
    await (database.update(database.healthRecords)
          ..where((row) => row.id.equals(own.id)))
        .write(
          const HealthRecordsCompanion(
            deletedAt: Value(2),
            updatedAt: Value(2),
          ),
        );

    expect(await repository.getByDate('2026-07-14'), isNull);
    expect(await repository.listRecent(), isEmpty);
    expect(bootstrap.activeUserId, isNot(otherUserId));
    expect(await database.select(database.healthRecords).get(), hasLength(2));
  });

  test('create writes active installation as originDeviceId', () async {
    await repository.saveForDate(
      HealthSaveData(recordDate: '2026-07-14', weightKg: 65.2),
    );
    final raw = await database.select(database.healthRecords).getSingle();
    final settings = await database.select(database.appSettings).getSingle();

    expect(raw.originDeviceId, settings.localInstallationId);
    expect(database.schemaVersion, 3);
  });

  test('Today health save is readable through Health', () async {
    final todayRepository = TodayRepositoryImpl(
      database: database,
      dateTimeService: DateTimeService(now: () => currentTime),
    );
    await todayRepository.saveToday(
      TodaySaveData(
        health: const TodayHealthInput(
          sleepDurationMinutes: 450,
          exerciseDurationMinutes: 30,
          physicalStateScore: 4,
        ),
      ),
    );

    final health = await repository.getToday();
    expect(health.sleepDurationMinutes, 450);
    expect(health.exerciseDurationMinutes, 30);
    expect(health.physicalStateScore, 4);
    expect(await database.select(database.healthRecords).get(), hasLength(1));
  });

  test('Health save is aggregated by Today without duplicate records', () async {
    await repository.saveForDate(
      HealthSaveData(
        recordDate: '2026-07-14',
        sleepDurationMinutes: 0,
        exerciseDurationMinutes: 45,
        physicalStateScore: 3,
      ),
    );
    final todayRepository = TodayRepositoryImpl(
      database: database,
      dateTimeService: DateTimeService(now: () => currentTime),
    );
    final today = await todayRepository.getToday();

    expect(today.health?.sleepDurationMinutes, 0);
    expect(today.health?.exerciseDurationMinutes, 45);
    expect(today.health?.physicalStateScore, 3);
    expect(await database.select(database.healthRecords).get(), hasLength(1));
  });

  test('Health links an existing Today record but never creates one', () async {
    await repository.saveForDate(
      HealthSaveData(recordDate: '2026-07-13', waterIntakeMl: 1000),
    );
    expect(await database.select(database.todayRecords).get(), isEmpty);

    final todayRepository = TodayRepositoryImpl(
      database: database,
      dateTimeService: DateTimeService(now: () => currentTime),
    );
    final today = await todayRepository.getToday();
    final health = await repository.saveForDate(
      HealthSaveData(recordDate: '2026-07-14', waterIntakeMl: 1500),
    );

    expect(health.todayRecordId, today.id);
    expect(await database.select(database.todayRecords).get(), hasLength(1));
  });
}
