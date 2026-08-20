import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/health/domain/health_entry.dart';
import 'package:rebirth/features/home/domain/home_overview.dart';
import 'package:rebirth/features/home/presentation/home_controller.dart';
import 'package:rebirth/features/home/presentation/home_page.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';

void main() {
  testWidgets('Home renders real Today and Health summaries', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dateTimeServiceProvider.overrideWithValue(
            DateTimeService(now: () => DateTime(2026, 8, 20, 9, 5)),
          ),
          homeOverviewProvider.overrideWith(
            (ref) async => HomeOverview(
              recordDate: '2026-08-20',
              today: _today(),
              health: _health(),
            ),
          ),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('productionHomePage')), findsOneWidget);
    expect(find.text('完成生产接入'), findsOneWidget);
    expect(find.text('心情 · 8 / 10'), findsOneWidget);
    expect(find.text('饮水 · 1250 ml'), findsOneWidget);
    for (final module in [
      'Today',
      'Journal',
      'Plan',
      'Health',
      'Growth',
      'AI Coach',
    ]) {
      expect(find.text(module), findsOneWidget);
    }
    expect(find.text('本地固定寄语 · 不调用 AI'), findsOneWidget);
  });

  testWidgets('Home keeps available content on a partial failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dateTimeServiceProvider.overrideWithValue(
            DateTimeService(now: () => DateTime(2026, 8, 20, 9, 5)),
          ),
          homeOverviewProvider.overrideWith(
            (ref) async => HomeOverview(
              recordDate: '2026-08-20',
              today: _today(),
              health: null,
              healthError: StateError('health unavailable'),
            ),
          ),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('homePartialFailure')), findsOneWidget);
    expect(find.text('完成生产接入'), findsOneWidget);
    expect(find.text('饮水 · 未记录'), findsOneWidget);
  });

  testWidgets('Home has no overflow at 320px and TextScaler 2.0', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dateTimeServiceProvider.overrideWithValue(
            DateTimeService(now: () => DateTime(2026, 8, 20, 9, 5)),
          ),
          homeOverviewProvider.overrideWith(
            (ref) async => HomeOverview(
              recordDate: '2026-08-20',
              today: _today(),
              health: _health(),
            ),
          ),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: HomePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('Home presentation keeps database implementation outside Widgets', () {
    for (final path in [
      'lib/features/home/presentation/home_page.dart',
      'lib/features/home/presentation/home_controller.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('package:drift')));
      expect(source, isNot(contains('app_database.dart')));
      expect(source, isNot(contains('repository_impl.dart')));
      expect(source, isNot(contains('local_data_source.dart')));
    }
  });
}

TodayEntry _today() => TodayEntry(
  id: 'today',
  userId: 'user-a',
  recordDate: '2026-08-20',
  timezoneOffsetMinutes: 480,
  priorities: const [
    TodayPriority(text: '完成生产接入', completed: true),
    TodayPriority(),
    TodayPriority(),
  ],
  moodScore: 8,
  energyScore: 7,
  researchMinutes: 90,
  learningMinutes: null,
  dailyNote: null,
  status: TodayRecordStatus.draft,
  createdAt: 1,
  updatedAt: 2,
  health: null,
);

HealthEntry _health() => const HealthEntry(
  id: 'health',
  userId: 'user-a',
  todayRecordId: 'today',
  recordDate: '2026-08-20',
  sleepDurationMinutes: 450,
  weightKg: 65,
  waterIntakeMl: 1250,
  exerciseDurationMinutes: 30,
  exerciseType: 'walk',
  physicalStateScore: 7,
  note: null,
  timezoneOffsetMinutes: 480,
  createdAt: 1,
  updatedAt: 2,
);
