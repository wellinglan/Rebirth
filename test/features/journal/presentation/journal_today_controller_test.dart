import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart' hide JournalEntry;
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/journal/data/journal_repository_provider.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_repository.dart';
import 'package:rebirth/features/journal/domain/journal_save_data.dart';
import 'package:rebirth/features/journal/presentation/journal_today_controller.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        dateTimeServiceProvider.overrideWithValue(
          DateTimeService(now: () => DateTime(2026, 7, 13, 21)),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('initial load returns null without a journal', () async {
    expect(
      container.read(journalTodayControllerProvider),
      isA<AsyncLoading<JournalEntry?>>(),
    );

    expect(await container.read(journalTodayControllerProvider.future), isNull);
  });

  test('initial load returns an existing today entry', () async {
    await container
        .read(journalRepositoryProvider)
        .saveTodayEntry(const JournalSaveData(learning: '已有复盘'));

    final entry = await container.read(journalTodayControllerProvider.future);

    expect(entry?.learning, '已有复盘');
  });

  test('successful save updates state', () async {
    await container.read(journalTodayControllerProvider.future);

    await container
        .read(journalTodayControllerProvider.notifier)
        .saveTodayEntry(const JournalSaveData(learning: 'Controller 保存'));

    expect(
      container.read(journalTodayControllerProvider).requireValue?.learning,
      'Controller 保存',
    );
  });

  test('failed save preserves the existing state', () async {
    await container
        .read(journalRepositoryProvider)
        .saveTodayEntry(const JournalSaveData(learning: '原有内容'));
    final existing = await container.read(
      journalTodayControllerProvider.future,
    );

    await expectLater(
      container
          .read(journalTodayControllerProvider.notifier)
          .saveTodayEntry(const JournalSaveData()),
      throwsA(isA<EmptyJournalContentException>()),
    );

    expect(
      container.read(journalTodayControllerProvider).requireValue?.id,
      existing?.id,
    );
    expect(
      container.read(journalTodayControllerProvider).requireValue?.learning,
      '原有内容',
    );
  });

  test('reload reads changes made outside the controller', () async {
    expect(await container.read(journalTodayControllerProvider.future), isNull);
    await container
        .read(journalRepositoryProvider)
        .saveTodayEntry(const JournalSaveData(learning: '重新加载内容'));

    await container.read(journalTodayControllerProvider.notifier).reload();

    expect(
      container.read(journalTodayControllerProvider).requireValue?.learning,
      '重新加载内容',
    );
  });
}
