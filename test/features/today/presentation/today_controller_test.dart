import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/presentation/today_controller.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        dateTimeServiceProvider.overrideWithValue(
          DateTimeService(now: () => DateTime(2026, 7, 10, 9)),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('loads Today, saves input, and exposes validation errors', () async {
    expect(
      container.read(todayControllerProvider),
      isA<AsyncLoading<TodayEntry>>(),
    );

    final initial = await container.read(todayControllerProvider.future);
    expect(initial.recordDate, '2026-07-10');

    await container
        .read(todayControllerProvider.notifier)
        .updateDailyNote('Controller 保存成功');
    expect(
      container.read(todayControllerProvider).requireValue.dailyNote,
      'Controller 保存成功',
    );

    await expectLater(
      container
          .read(todayControllerProvider.notifier)
          .updateMoodEnergy(moodScore: 6),
      throwsArgumentError,
    );
    expect(
      container.read(todayControllerProvider).requireValue.dailyNote,
      'Controller 保存成功',
    );
  });
}
