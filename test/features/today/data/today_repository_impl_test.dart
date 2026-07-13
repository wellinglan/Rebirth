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
}
