import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/health/domain/health_save_data.dart';
import 'package:rebirth/features/health/presentation/health_controller.dart';
import 'package:rebirth/features/today/domain/today_save_data.dart';
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
          DateTimeService(now: () => DateTime(2026, 7, 14, 9)),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('Today and Health refresh each other without an app restart', () async {
    await Future.wait([
      container.read(todayControllerProvider.future),
      container.read(healthControllerProvider.future),
    ]);

    await container
        .read(todayControllerProvider.notifier)
        .saveToday(
          TodaySaveData(
            researchMinutes: 0,
            learningMinutes: null,
            health: const TodayHealthInput(
              sleepDurationMinutes: 450,
              exerciseDurationMinutes: null,
              physicalStateScore: 4,
            ),
          ),
        );

    final healthAfterToday = await container.read(
      healthControllerProvider.future,
    );
    expect(healthAfterToday.today.sleepDurationMinutes, 450);
    expect(healthAfterToday.today.exerciseDurationMinutes, isNull);
    expect(healthAfterToday.summary.recordsCount, 1);
    expect(healthAfterToday.recentEntries, isEmpty);

    await container
        .read(healthControllerProvider.notifier)
        .saveToday(
          HealthSaveData(
            recordDate: '2026-07-14',
            sleepDurationMinutes: 480,
            exerciseDurationMinutes: 0,
            physicalStateScore: null,
          ),
        );

    final todayAfterHealth = await container.read(
      todayControllerProvider.future,
    );
    expect(todayAfterHealth.researchMinutes, 0);
    expect(todayAfterHealth.learningMinutes, isNull);
    expect(todayAfterHealth.health?.sleepDurationMinutes, 480);
    expect(todayAfterHealth.health?.exerciseDurationMinutes, 0);
    expect(todayAfterHealth.health?.physicalStateScore, isNull);

    final healthRows = await database.select(database.healthRecords).get();
    expect(healthRows, hasLength(1));
  });

  test('cross-module invalidation keeps presentation dependencies one-way', () {
    final todaySource = File(
      'lib/features/today/presentation/today_controller.dart',
    ).readAsStringSync();
    final healthSource = File(
      'lib/features/health/presentation/health_controller.dart',
    ).readAsStringSync();
    final revisionSource = File(
      'lib/shared/state/health_record_revision_provider.dart',
    ).readAsStringSync();

    expect(todaySource, isNot(contains('features/health/presentation')));
    expect(healthSource, isNot(contains('features/today/presentation')));
    expect(revisionSource, isNot(contains('features/')));
    expect(revisionSource, isNot(contains('AppDatabase')));
  });
}
