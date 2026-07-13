import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/journal/data/journal_repository_impl.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart' as domain;
import 'package:rebirth/features/journal/domain/journal_repository.dart';
import 'package:rebirth/features/journal/domain/journal_save_data.dart';
import 'package:uuid/uuid.dart';

void main() {
  const uuid = Uuid();
  late AppDatabase database;
  late DateTime currentTime;
  late int clockReads;
  late JournalRepositoryImpl repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    currentTime = DateTime(2026, 7, 10, 21, 30);
    clockReads = 0;
    repository = JournalRepositoryImpl(
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

  test('createEntry trims content and uses one currentSnapshot', () async {
    final entry = await repository.createEntry(
      const JournalSaveData(
        mostImportantAccomplishment: '  完成实验设计  ',
        learning: '  学会了新的分析方法  ',
        status: domain.JournalEntryStatus.completed,
      ),
    );
    final rawEntry = await database.select(database.journalEntries).getSingle();
    final settings = await database.select(database.appSettings).getSingle();

    expect(clockReads, 1);
    expect(entry.entryDate, '2026-07-10');
    expect(entry.timezoneOffsetMinutes, currentTime.timeZoneOffset.inMinutes);
    expect(entry.createdAt, currentTime.toUtc().millisecondsSinceEpoch);
    expect(entry.updatedAt, currentTime.toUtc().millisecondsSinceEpoch);
    expect(entry.mostImportantAccomplishment, '完成实验设计');
    expect(entry.learning, '学会了新的分析方法');
    expect(entry.status, domain.JournalEntryStatus.completed);
    expect(rawEntry.originDeviceId, settings.localInstallationId);
  });

  test('createEntry rejects empty or whitespace-only content', () async {
    await expectLater(
      repository.createEntry(const JournalSaveData()),
      throwsA(isA<EmptyJournalContentException>()),
    );
    await expectLater(
      repository.createEntry(
        const JournalSaveData(
          mostImportantAccomplishment: '  ',
          mostDrainingEvent: '\n\t',
        ),
      ),
      throwsA(isA<EmptyJournalContentException>()),
    );

    expect(await database.select(database.journalEntries).get(), isEmpty);
    expect(clockReads, 0);
  });

  test('blank optional answers are stored as null', () async {
    final entry = await repository.createEntry(
      const JournalSaveData(
        mostImportantAccomplishment: '完成核心任务',
        mostDrainingEvent: ' ',
        emotionSource: '',
        learning: '\n',
        tomorrowAdjustment: '\t',
      ),
    );

    expect(entry.mostDrainingEvent, isNull);
    expect(entry.emotionSource, isNull);
    expect(entry.learning, isNull);
    expect(entry.tomorrowAdjustment, isNull);
  });

  test('getById reads an active entry', () async {
    final created = await repository.createEntry(
      const JournalSaveData(emotionSource: '对实验进度的担心'),
    );

    final loaded = await repository.getById(created.id);

    expect(loaded, isNotNull);
    expect(loaded!.id, created.id);
    expect(loaded.emotionSource, '对实验进度的担心');
  });

  test('listRecent orders by updatedAt descending', () async {
    currentTime = DateTime(2026, 7, 8, 20);
    final first = await repository.createEntry(
      const JournalSaveData(learning: '第一篇'),
    );
    currentTime = DateTime(2026, 7, 9, 20);
    final second = await repository.createEntry(
      const JournalSaveData(learning: '第二篇'),
    );
    currentTime = DateTime(2026, 7, 10, 20);
    await repository.updateEntry(
      id: first.id,
      data: const JournalSaveData(learning: '第一篇已更新'),
    );

    final entries = await repository.listRecent();

    expect(entries.map((entry) => entry.id), [first.id, second.id]);
  });

  test(
    'listByDate and inclusive date range only return matching entries',
    () async {
      final entriesByDate = <String, domain.JournalEntry>{};
      for (final day in [8, 9, 10]) {
        currentTime = DateTime(2026, 7, day, 20);
        entriesByDate['2026-07-${day.toString().padLeft(2, '0')}'] =
            await repository.createEntry(JournalSaveData(learning: '第 $day 天'));
      }

      final exact = await repository.listByDate('2026-07-09');
      final range = await repository.listByDateRange(
        startDate: '2026-07-08',
        endDate: '2026-07-09',
      );

      expect(exact.map((entry) => entry.id), [entriesByDate['2026-07-09']!.id]);
      expect(range.map((entry) => entry.id), [
        entriesByDate['2026-07-09']!.id,
        entriesByDate['2026-07-08']!.id,
      ]);
    },
  );

  test(
    'updateEntry replaces content and explicitly updates updatedAt',
    () async {
      final created = await repository.createEntry(
        const JournalSaveData(learning: '旧内容'),
      );
      currentTime = currentTime.add(const Duration(minutes: 15));

      final updated = await repository.updateEntry(
        id: created.id,
        data: const JournalSaveData(
          mostImportantAccomplishment: ' 新完成 ',
          mostDrainingEvent: ' 新消耗 ',
          emotionSource: ' 新情绪 ',
          learning: ' 新学习 ',
          tomorrowAdjustment: ' 新调整 ',
          status: domain.JournalEntryStatus.completed,
        ),
      );
      final rawEntry = await database
          .select(database.journalEntries)
          .getSingle();

      expect(updated.mostImportantAccomplishment, '新完成');
      expect(updated.mostDrainingEvent, '新消耗');
      expect(updated.emotionSource, '新情绪');
      expect(updated.learning, '新学习');
      expect(updated.tomorrowAdjustment, '新调整');
      expect(updated.status, domain.JournalEntryStatus.completed);
      expect(updated.updatedAt, currentTime.toUtc().millisecondsSinceEpoch);
      expect(rawEntry.updatedAt, currentTime.toUtc().millisecondsSinceEpoch);
      expect(updated.updatedAt, greaterThan(created.updatedAt));
    },
  );

  test('softDelete hides but does not physically remove the row', () async {
    final created = await repository.createEntry(
      const JournalSaveData(learning: '即将软删除'),
    );
    currentTime = currentTime.add(const Duration(minutes: 10));
    final deletionTimestamp = currentTime.toUtc().millisecondsSinceEpoch;

    await repository.softDelete(created.id);

    expect(await repository.getById(created.id), isNull);
    expect(await repository.listRecent(), isEmpty);
    final rawRows = await database.select(database.journalEntries).get();
    expect(rawRows, hasLength(1));
    expect(rawRows.single.deletedAt, deletionTimestamp);
    expect(rawRows.single.updatedAt, deletionTimestamp);
  });

  test('queries never leak entries belonging to another user', () async {
    final ownEntry = await repository.createEntry(
      const JournalSaveData(learning: '当前用户内容'),
    );
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
    final otherEntryId = uuid.v4();
    await database
        .into(database.journalEntries)
        .insert(
          JournalEntriesCompanion.insert(
            id: Value(otherEntryId),
            userId: otherUserId,
            entryDate: ownEntry.entryDate,
            timezoneOffsetMinutes: 0,
            learning: const Value('其他用户内容'),
          ),
        );

    final entries = await repository.listRecent();

    expect(entries.map((entry) => entry.id), [ownEntry.id]);
    expect(entries.single.learning, '当前用户内容');
    expect(await repository.getById(otherEntryId), isNull);
  });

  test('createEntry links an active Today record on the same date', () async {
    final bootstrap = await database.bootstrapDao.bootstrap();
    final todayId = uuid.v4();
    await database
        .into(database.todayRecords)
        .insert(
          TodayRecordsCompanion.insert(
            id: Value(todayId),
            userId: bootstrap.activeUserId,
            recordDate: '2026-07-10',
            timezoneOffsetMinutes: currentTime.timeZoneOffset.inMinutes,
          ),
        );

    final entry = await repository.createEntry(
      const JournalSaveData(learning: '与 Today 同日'),
    );

    expect(entry.todayRecordId, todayId);
  });

  test('date ranges and limits reject invalid arguments', () async {
    await expectLater(repository.listByDate('2026-02-30'), throwsArgumentError);
    await expectLater(repository.listRecent(limit: 0), throwsArgumentError);
    await expectLater(
      repository.listByDateRange(
        startDate: '2026-07-11',
        endDate: '2026-07-10',
      ),
      throwsArgumentError,
    );
  });

  test('updating or deleting an unknown entry fails clearly', () async {
    await expectLater(
      repository.updateEntry(
        id: uuid.v4(),
        data: const JournalSaveData(learning: '不会保存'),
      ),
      throwsA(isA<JournalEntryNotFoundException>()),
    );
    await expectLater(
      repository.softDelete(uuid.v4()),
      throwsA(isA<JournalEntryNotFoundException>()),
    );
  });

  test('getTodayEntry returns null when today has no journal', () async {
    final entry = await repository.getTodayEntry();

    expect(entry, isNull);
    expect(clockReads, 1);
  });

  test('saveTodayEntry creates and can be read as today entry', () async {
    final saved = await repository.saveTodayEntry(
      const JournalSaveData(learning: '今日第一次保存'),
    );
    final loaded = await repository.getTodayEntry();

    expect(saved.entryDate, '2026-07-10');
    expect(loaded?.id, saved.id);
    expect(loaded?.learning, '今日第一次保存');
  });

  test('saveTodayEntry updates the same row and updatedAt', () async {
    final first = await repository.saveTodayEntry(
      const JournalSaveData(learning: '第一次内容'),
    );
    currentTime = currentTime.add(const Duration(minutes: 20));

    final second = await repository.saveTodayEntry(
      const JournalSaveData(learning: '第二次内容', tomorrowAdjustment: '明天减少干扰'),
    );

    expect(second.id, first.id);
    expect(second.learning, '第二次内容');
    expect(second.updatedAt, currentTime.toUtc().millisecondsSinceEpoch);
    expect(second.updatedAt, greaterThan(first.updatedAt));
    expect(await database.select(database.journalEntries).get(), hasLength(1));
  });

  test('saveTodayEntry rejects all-empty content before writing', () async {
    await expectLater(
      repository.saveTodayEntry(
        const JournalSaveData(learning: ' ', tomorrowAdjustment: '\n'),
      ),
      throwsA(isA<EmptyJournalContentException>()),
    );

    expect(await database.select(database.journalEntries).get(), isEmpty);
    expect(clockReads, 0);
    expect(database.schemaVersion, 1);
  });
}
