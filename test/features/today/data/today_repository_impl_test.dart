import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/today/data/today_repository_impl.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_save_data.dart';
import 'package:uuid/uuid.dart';

void main() {
  const uuid = Uuid();
  late AppDatabase database;
  late DateTime currentTime;
  late int clockReads;
  late TodayRepositoryImpl repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    currentTime = DateTime(2026, 7, 10, 9, 30);
    clockReads = 0;
    repository = TodayRepositoryImpl(
      database: database,
      dateTimeService: DateTimeService(
        now: () {
          clockReads += 1;
          return currentTime;
        },
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('first getToday creates a record from currentSnapshot', () async {
    final entry = await repository.getToday();
    final rawRecord = await database.select(database.todayRecords).getSingle();
    final settings = await database.select(database.appSettings).getSingle();

    expect(clockReads, 1);
    expect(entry.recordDate, '2026-07-10');
    expect(entry.timezoneOffsetMinutes, currentTime.timeZoneOffset.inMinutes);
    expect(entry.createdAt, currentTime.toUtc().millisecondsSinceEpoch);
    expect(entry.updatedAt, currentTime.toUtc().millisecondsSinceEpoch);
    expect(rawRecord.originDeviceId, settings.localInstallationId);
  });

  test('repeated getToday does not create a duplicate', () async {
    final first = await repository.getToday();
    final second = await repository.getToday();

    expect(second.id, first.id);
    expect(await database.select(database.todayRecords).get(), hasLength(1));
  });

  test('same user and date unique constraint remains effective', () async {
    final existing = await repository.getToday();

    await expectLater(
      database
          .into(database.todayRecords)
          .insert(
            TodayRecordsCompanion.insert(
              id: Value(uuid.v4()),
              userId: existing.userId,
              recordDate: existing.recordDate,
              timezoneOffsetMinutes: existing.timezoneOffsetMinutes,
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('research minutes keeps NULL and zero distinct', () async {
    final initial = await repository.getToday();
    expect(initial.researchMinutes, isNull);

    final zero = await repository.updateResearchLearningMinutes(
      recordDate: initial.recordDate,
      researchMinutes: 0,
      learningMinutes: null,
    );
    expect(zero.researchMinutes, 0);

    final cleared = await repository.updateResearchLearningMinutes(
      recordDate: initial.recordDate,
      researchMinutes: null,
      learningMinutes: null,
    );
    expect(cleared.researchMinutes, isNull);
  });

  test('mood and energy score validation accepts only 1 through 5', () async {
    final entry = await repository.getToday();

    await expectLater(
      repository.updateMoodEnergy(
        recordDate: entry.recordDate,
        moodScore: 0,
        energyScore: null,
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.updateMoodEnergy(
        recordDate: entry.recordDate,
        moodScore: null,
        energyScore: 6,
      ),
      throwsArgumentError,
    );

    final updated = await repository.updateMoodEnergy(
      recordDate: entry.recordDate,
      moodScore: 1,
      energyScore: 5,
    );
    expect(updated.moodScore, 1);
    expect(updated.energyScore, 5);
  });

  test('daily note can be saved and updated', () async {
    final entry = await repository.getToday();

    final saved = await repository.updateDailyNote(
      recordDate: entry.recordDate,
      dailyNote: '完成了实验设计',
    );
    final updated = await repository.updateDailyNote(
      recordDate: entry.recordDate,
      dailyNote: '完成了实验设计并记录结果',
    );

    expect(saved.dailyNote, '完成了实验设计');
    expect(updated.dailyNote, '完成了实验设计并记录结果');
  });

  test('empty priority completion does not count in business totals', () async {
    final entry = await repository.getToday();
    final updated = await repository.updatePriorities(
      recordDate: entry.recordDate,
      priorities: const <TodayPriority>[
        TodayPriority(completed: true),
        TodayPriority(text: '阅读论文', completed: true),
        TodayPriority(text: '整理笔记'),
      ],
    );

    expect(updated.populatedPriorityCount, 2);
    expect(updated.completedPriorityCount, 1);
  });

  test('Today and Health records aggregate by local date', () async {
    final saved = await repository.saveToday(
      TodaySaveData(
        moodScore: 4,
        health: const TodayHealthInput(
          sleepDurationMinutes: 450,
          exerciseType: 'running',
          exerciseDurationMinutes: 30,
          physicalStateScore: 4,
        ),
      ),
    );
    final loaded = await repository.getByDate(saved.recordDate);
    final rawHealth = await database.select(database.healthRecords).getSingle();

    expect(loaded, isNotNull);
    expect(loaded!.health, isNotNull);
    expect(loaded.health!.sleepDurationMinutes, 450);
    expect(loaded.health!.exerciseType, 'running');
    expect(rawHealth.todayRecordId, saved.id);
    expect(rawHealth.recordDate, saved.recordDate);
  });

  test('Today and Health save rolls back as one transaction', () async {
    await repository.getToday();
    await database.customStatement('''
      CREATE TRIGGER reject_health_insert
      BEFORE INSERT ON health_records
      BEGIN
        SELECT RAISE(ABORT, 'health insert rejected for test');
      END
    ''');

    await expectLater(
      repository.saveToday(
        TodaySaveData(
          dailyNote: 'this change must roll back',
          health: const TodayHealthInput(sleepDurationMinutes: 420),
        ),
      ),
      throwsA(isA<Exception>()),
    );

    final rawToday = await database.select(database.todayRecords).getSingle();
    expect(rawToday.dailyNote, isNull);
    expect(await database.select(database.healthRecords).get(), isEmpty);
  });

  test('updates explicitly replace updatedAt with snapshot time', () async {
    final created = await repository.getToday();
    currentTime = currentTime.add(const Duration(minutes: 5));

    final updated = await repository.updateDailyNote(
      recordDate: created.recordDate,
      dailyNote: '新的记录',
    );
    final rawRecord = await database.select(database.todayRecords).getSingle();

    expect(updated.updatedAt, currentTime.toUtc().millisecondsSinceEpoch);
    expect(rawRecord.updatedAt, currentTime.toUtc().millisecondsSinceEpoch);
    expect(updated.updatedAt, greaterThan(created.updatedAt));
  });

  test('history query returns empty without creating records', () async {
    final entries = await repository.listRecentEntries();

    expect(entries, isEmpty);
    expect(await database.select(database.todayRecords).get(), isEmpty);
  });

  test('recent entries are date-descending and days are enforced', () async {
    for (final day in [10, 11, 13]) {
      currentTime = DateTime(2026, 7, day, 9);
      await repository.saveToday(TodaySaveData(dailyNote: '第 $day 天'));
    }

    final threeDays = await repository.listRecentEntries(days: 4);
    final twoDays = await repository.listRecentEntries(days: 2);

    expect(threeDays.map((entry) => entry.recordDate), [
      '2026-07-13',
      '2026-07-11',
      '2026-07-10',
    ]);
    expect(twoDays.map((entry) => entry.recordDate), ['2026-07-13']);
    expect(await database.select(database.todayRecords).get(), hasLength(3));
  });

  test('date range limit applies without creating missing dates', () async {
    for (final day in [10, 11, 12]) {
      currentTime = DateTime(2026, 7, day, 9);
      await repository.saveToday(TodaySaveData(dailyNote: '第 $day 天'));
    }

    final entries = await repository.listByDateRange(
      startDate: '2026-07-01',
      endDate: '2026-07-31',
      limit: 2,
    );

    expect(entries.map((entry) => entry.recordDate), [
      '2026-07-12',
      '2026-07-11',
    ]);
    expect(await database.select(database.todayRecords).get(), hasLength(3));
  });

  test('history excludes soft-deleted Today records', () async {
    final entry = await repository.saveToday(TodaySaveData(dailyNote: '即将软删除'));
    await (database.update(
      database.todayRecords,
    )..where((row) => row.id.equals(entry.id))).write(
      const TodayRecordsCompanion(deletedAt: Value(1), updatedAt: Value(1)),
    );

    expect(await repository.listRecentEntries(), isEmpty);
    expect(await database.select(database.todayRecords).get(), hasLength(1));
  });

  test('history aggregates the Health record from the same date', () async {
    await repository.saveToday(
      TodaySaveData(
        dailyNote: '包含健康摘要',
        health: const TodayHealthInput(
          sleepDurationMinutes: 450,
          exerciseDurationMinutes: 30,
          physicalStateScore: 4,
        ),
      ),
    );

    final entry = (await repository.listRecentEntries()).single;

    expect(entry.health?.sleepDurationMinutes, 450);
    expect(entry.health?.exerciseDurationMinutes, 30);
    expect(entry.health?.physicalStateScore, 4);
  });

  test('history never leaks records from another user', () async {
    final own = await repository.saveToday(TodaySaveData(dailyNote: '当前用户记录'));
    final otherUserId = uuid.v4();
    await database
        .into(database.userProfiles)
        .insert(
          UserProfilesCompanion.insert(
            id: Value(otherUserId),
            timezoneId: 'Etc/UTC',
            isActive: const Value(false),
          ),
        );
    await database
        .into(database.todayRecords)
        .insert(
          TodayRecordsCompanion.insert(
            id: Value(uuid.v4()),
            userId: otherUserId,
            recordDate: own.recordDate,
            timezoneOffsetMinutes: 0,
            dailyNote: const Value('其他用户记录'),
          ),
        );

    final entries = await repository.listRecentEntries();

    expect(entries, hasLength(1));
    expect(entries.single.id, own.id);
    expect(entries.single.dailyNote, '当前用户记录');
  });

  test('history arguments are validated and getToday still creates', () async {
    await expectLater(
      repository.listRecentEntries(days: 0),
      throwsArgumentError,
    );
    await expectLater(
      repository.listByDateRange(
        startDate: '2026-07-13',
        endDate: '2026-07-12',
      ),
      throwsArgumentError,
    );

    final today = await repository.getToday();
    expect(today.recordDate, '2026-07-10');
    expect(await database.select(database.todayRecords).get(), hasLength(1));
  });
}
