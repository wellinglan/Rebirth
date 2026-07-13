import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/journal/data/journal_repository_impl.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart' as domain;
import 'package:rebirth/features/journal/domain/journal_save_data.dart';

void main() {
  late Directory temporaryDirectory;
  late File databaseFile;
  AppDatabase? openDatabase;
  var currentTime = DateTime(2026, 7, 13, 21);

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'rebirth_journal_persistence_',
    );
    databaseFile = File('${temporaryDirectory.path}/rebirth.sqlite');
    currentTime = DateTime(2026, 7, 13, 21);
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

  JournalRepositoryImpl openRepository() {
    final database = AppDatabase.forTesting(NativeDatabase(databaseFile));
    openDatabase = database;
    return JournalRepositoryImpl(
      database: database,
      dateTimeService: DateTimeService(now: () => currentTime),
    );
  }

  test('today journal survives recreation and updates the same row', () async {
    final firstRepository = openRepository();
    final firstSave = await firstRepository.saveTodayEntry(
      const JournalSaveData(
        mostImportantAccomplishment: '完成关键实验',
        mostDrainingEvent: '等待实验结果',
        emotionSource: '对进度的担心',
        learning: '先验证最小假设',
        tomorrowAdjustment: '优先整理数据',
        status: domain.JournalEntryStatus.completed,
      ),
    );

    await closeDatabase();

    final secondRepository = openRepository();
    final afterFirstRestart = await secondRepository.getTodayEntry();
    final firstHistory = await secondRepository.listRecent();

    expect(afterFirstRestart?.id, firstSave.id);
    expect(afterFirstRestart?.mostImportantAccomplishment, '完成关键实验');
    expect(afterFirstRestart?.mostDrainingEvent, '等待实验结果');
    expect(afterFirstRestart?.emotionSource, '对进度的担心');
    expect(afterFirstRestart?.learning, '先验证最小假设');
    expect(afterFirstRestart?.tomorrowAdjustment, '优先整理数据');
    expect(firstHistory, hasLength(1));
    expect(firstHistory.single.id, firstSave.id);

    currentTime = currentTime.add(const Duration(minutes: 30));
    final updated = await secondRepository.saveTodayEntry(
      const JournalSaveData(
        mostImportantAccomplishment: '完成实验并整理结果',
        learning: '记录过程同样重要',
      ),
    );
    expect(updated.id, firstSave.id);

    await closeDatabase();

    final thirdRepository = openRepository();
    final afterSecondRestart = await thirdRepository.getTodayEntry();
    final secondHistory = await thirdRepository.listRecent();
    final rawRows = await openDatabase!
        .select(openDatabase!.journalEntries)
        .get();

    expect(afterSecondRestart?.id, firstSave.id);
    expect(afterSecondRestart?.mostImportantAccomplishment, '完成实验并整理结果');
    expect(afterSecondRestart?.mostDrainingEvent, isNull);
    expect(afterSecondRestart?.emotionSource, isNull);
    expect(afterSecondRestart?.learning, '记录过程同样重要');
    expect(afterSecondRestart?.tomorrowAdjustment, isNull);
    expect(secondHistory, hasLength(1));
    expect(secondHistory.single.id, firstSave.id);
    expect(secondHistory.single.learning, '记录过程同样重要');
    expect(rawRows.where((row) => row.deletedAt == null), hasLength(1));
  });
}
