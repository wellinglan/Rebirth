import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/today/data/today_repository_provider.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_repository.dart';
import 'package:rebirth/features/today/domain/today_save_data.dart';
import 'package:rebirth/features/today/presentation/today_controller.dart';
import 'package:rebirth/features/today/presentation/today_history_controller.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;
  late DateTime currentTime;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    currentTime = DateTime(2026, 7, 13, 9);
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        dateTimeServiceProvider.overrideWithValue(
          DateTimeService(now: () => currentTime),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('initial history load is empty and does not create Today', () async {
    expect(
      container.read(todayHistoryControllerProvider),
      isA<AsyncLoading<List<TodayEntry>>>(),
    );

    expect(
      await container.read(todayHistoryControllerProvider.future),
      isEmpty,
    );
    expect(await database.select(database.todayRecords).get(), isEmpty);
  });

  test('initial load returns multiple recent dates', () async {
    final repository = container.read(todayRepositoryProvider);
    currentTime = DateTime(2026, 7, 12, 9);
    await repository.saveToday(TodaySaveData(dailyNote: '十二日'));
    currentTime = DateTime(2026, 7, 13, 9);
    await repository.saveToday(TodaySaveData(dailyNote: '十三日'));

    final entries = await container.read(todayHistoryControllerProvider.future);

    expect(entries.map((entry) => entry.recordDate), [
      '2026-07-13',
      '2026-07-12',
    ]);
  });

  test('reload reads records saved after the initial load', () async {
    expect(
      await container.read(todayHistoryControllerProvider.future),
      isEmpty,
    );
    await container
        .read(todayRepositoryProvider)
        .saveToday(TodaySaveData(dailyNote: '重新加载'));

    await container.read(todayHistoryControllerProvider.notifier).reload();

    expect(
      container
          .read(todayHistoryControllerProvider)
          .requireValue
          .single
          .dailyNote,
      '重新加载',
    );
  });

  test('repository errors become history AsyncError', () async {
    final errorContainer = ProviderContainer(
      overrides: [
        todayRepositoryProvider.overrideWithValue(_FailingTodayRepository()),
      ],
    );
    addTearDown(errorContainer.dispose);

    await expectLater(
      errorContainer.read(todayHistoryControllerProvider.future),
      throwsA(isA<StateError>()),
    );
    expect(
      errorContainer.read(todayHistoryControllerProvider),
      isA<AsyncError<List<TodayEntry>>>(),
    );
  });

  test('history errors do not alter TodayController state', () async {
    final today = await container.read(todayControllerProvider.future);
    await container.read(todayHistoryControllerProvider.future);

    await expectLater(
      container
          .read(todayHistoryControllerProvider.notifier)
          .loadRecent(days: 0),
      throwsArgumentError,
    );

    expect(container.read(todayHistoryControllerProvider).hasError, isTrue);
    expect(container.read(todayControllerProvider).requireValue.id, today.id);
  });
}

final class _FailingTodayRepository implements TodayRepository {
  @override
  Future<List<TodayEntry>> listRecentEntries({int days = 30}) {
    throw StateError('history failed for test');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
