import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/today/data/today_repository_impl.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_save_data.dart';

void main() {
  late Directory temporaryDirectory;
  late File databaseFile;
  AppDatabase? openDatabase;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'rebirth_today_persistence_',
    );
    databaseFile = File('${temporaryDirectory.path}/rebirth.sqlite');
  });

  tearDown(() async {
    await openDatabase?.close();
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  Future<void> closeDatabase() async {
    await openDatabase?.close();
    openDatabase = null;
  }

  TodayRepositoryImpl openRepository() {
    final database = AppDatabase.forTesting(NativeDatabase(databaseFile));
    openDatabase = database;
    return TodayRepositoryImpl(
      database: database,
      dateTimeService: DateTimeService(now: () => DateTime(2026, 7, 13, 9, 30)),
    );
  }

  test('Today data survives database and repository recreation', () async {
    final firstRepository = openRepository();
    final firstSave = await firstRepository.saveToday(
      TodaySaveData(
        priorities: const <TodayPriority>[
          TodayPriority(text: '完成实验', completed: true),
          TodayPriority(text: '阅读论文'),
          TodayPriority(text: '整理数据'),
        ],
        moodScore: 4,
        energyScore: 3,
        researchMinutes: 90,
        learningMinutes: 45,
        dailyNote: '第一轮持久化记录',
        health: const TodayHealthInput(
          sleepDurationMinutes: 450,
          weightKg: 68.5,
          waterIntakeMl: 1800,
          exerciseType: 'running',
          exerciseDurationMinutes: 35,
          physicalStateScore: 4,
          note: '隐藏健康字段必须保留',
        ),
      ),
    );

    await closeDatabase();

    final secondRepository = openRepository();
    final afterFirstRestart = await secondRepository.getToday();

    expect(afterFirstRestart.id, firstSave.id);
    expect(afterFirstRestart.priorities[0].text, '完成实验');
    expect(afterFirstRestart.priorities[0].completed, isTrue);
    expect(afterFirstRestart.priorities[1].text, '阅读论文');
    expect(afterFirstRestart.priorities[2].text, '整理数据');
    expect(afterFirstRestart.moodScore, 4);
    expect(afterFirstRestart.energyScore, 3);
    expect(afterFirstRestart.researchMinutes, 90);
    expect(afterFirstRestart.learningMinutes, 45);
    expect(afterFirstRestart.dailyNote, '第一轮持久化记录');
    expect(afterFirstRestart.health?.sleepDurationMinutes, 450);
    expect(afterFirstRestart.health?.exerciseDurationMinutes, 35);
    expect(afterFirstRestart.health?.physicalStateScore, 4);

    final health = afterFirstRestart.health!;
    await secondRepository.saveToday(
      TodaySaveData(
        priorities: afterFirstRestart.priorities,
        moodScore: afterFirstRestart.moodScore,
        energyScore: afterFirstRestart.energyScore,
        researchMinutes: null,
        learningMinutes: 0,
        dailyNote: '第二轮持久化记录',
        status: afterFirstRestart.status,
        health: TodayHealthInput(
          sleepDurationMinutes: health.sleepDurationMinutes,
          weightKg: health.weightKg,
          waterIntakeMl: health.waterIntakeMl,
          exerciseType: health.exerciseType,
          exerciseDurationMinutes: health.exerciseDurationMinutes,
          physicalStateScore: health.physicalStateScore,
          note: health.note,
        ),
      ),
    );

    await closeDatabase();

    final thirdRepository = openRepository();
    final afterSecondRestart = await thirdRepository.getByDate('2026-07-13');

    expect(afterSecondRestart, isNotNull);
    expect(afterSecondRestart!.researchMinutes, isNull);
    expect(afterSecondRestart.learningMinutes, 0);
    expect(afterSecondRestart.dailyNote, '第二轮持久化记录');
    expect(afterSecondRestart.health?.sleepDurationMinutes, 450);
    expect(afterSecondRestart.health?.exerciseDurationMinutes, 35);
    expect(afterSecondRestart.health?.physicalStateScore, 4);
    expect(afterSecondRestart.health?.weightKg, 68.5);
    expect(afterSecondRestart.health?.waterIntakeMl, 1800);
    expect(afterSecondRestart.health?.exerciseType, 'running');
    expect(afterSecondRestart.health?.note, '隐藏健康字段必须保留');
  });
}
