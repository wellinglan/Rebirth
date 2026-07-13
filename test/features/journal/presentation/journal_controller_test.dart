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
import 'package:rebirth/features/journal/presentation/journal_controller.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        dateTimeServiceProvider.overrideWithValue(
          DateTimeService(now: () => DateTime(2026, 7, 10, 21)),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('loads, creates, updates, and soft deletes recent entries', () async {
    expect(
      container.read(journalControllerProvider),
      isA<AsyncLoading<List<JournalEntry>>>(),
    );
    expect(await container.read(journalControllerProvider.future), isEmpty);

    final controller = container.read(journalControllerProvider.notifier);
    await controller.createEntry(
      const JournalSaveData(learning: 'Controller 创建'),
    );
    final created = container
        .read(journalControllerProvider)
        .requireValue
        .single;
    expect(created.learning, 'Controller 创建');

    await controller.updateEntry(
      id: created.id,
      data: const JournalSaveData(learning: 'Controller 更新'),
    );
    expect(
      container.read(journalControllerProvider).requireValue.single.learning,
      'Controller 更新',
    );

    await controller.deleteEntry(created.id);
    expect(container.read(journalControllerProvider).requireValue, isEmpty);
  });

  test('exposes repository failures as AsyncError', () async {
    await container.read(journalControllerProvider.future);
    final controller = container.read(journalControllerProvider.notifier);

    await expectLater(
      controller.createEntry(const JournalSaveData()),
      throwsA(isA<EmptyJournalContentException>()),
    );

    expect(
      container.read(journalControllerProvider),
      isA<AsyncError<List<JournalEntry>>>(),
    );
  });

  test('reload reads newly saved recent entries', () async {
    expect(await container.read(journalControllerProvider.future), isEmpty);
    await container
        .read(journalRepositoryProvider)
        .saveTodayEntry(const JournalSaveData(learning: '外部保存'));

    await container.read(journalControllerProvider.notifier).reload();

    expect(
      container.read(journalControllerProvider).requireValue.single.learning,
      '外部保存',
    );
  });

  test('initial repository failure exposes AsyncError', () async {
    final errorContainer = ProviderContainer(
      overrides: [
        journalRepositoryProvider.overrideWithValue(
          _FailingJournalRepository(),
        ),
      ],
    );
    addTearDown(errorContainer.dispose);

    await expectLater(
      errorContainer.read(journalControllerProvider.future),
      throwsA(isA<StateError>()),
    );
    expect(
      errorContainer.read(journalControllerProvider),
      isA<AsyncError<List<JournalEntry>>>(),
    );
  });
}

final class _FailingJournalRepository implements JournalRepository {
  @override
  Future<List<JournalEntry>> listRecent({int limit = 20}) {
    throw StateError('history load failed for test');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
