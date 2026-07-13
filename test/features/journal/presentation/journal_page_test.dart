import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/journal/domain/journal_save_data.dart';
import 'package:rebirth/features/journal/presentation/journal_controller.dart';
import 'package:rebirth/features/journal/presentation/journal_page.dart';

void main() {
  testWidgets('JournalPage shows empty state and recent entry count', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        dateTimeServiceProvider.overrideWithValue(
          DateTimeService(now: () => DateTime(2026, 7, 10, 21)),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: JournalPage())),
      ),
    );

    expect(find.byKey(const ValueKey('journalLoadingState')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('journalEmptyState')), findsOneWidget);

    await container
        .read(journalControllerProvider.notifier)
        .createEntry(const JournalSaveData(learning: '页面状态测试'));
    await tester.pump();

    expect(find.byKey(const ValueKey('journalCountState')), findsOneWidget);
    expect(find.text('最近复盘 1 篇'), findsOneWidget);
  });

  test('Journal widgets do not import database implementations', () {
    const journalPageSource =
        'lib/features/journal/presentation/journal_page.dart';
    const controllerSource =
        'lib/features/journal/presentation/journal_controller.dart';

    for (final source in [journalPageSource, controllerSource]) {
      final text = File(source).readAsStringSync();
      expect(text, isNot(contains('package:drift')));
      expect(text, isNot(contains('app_database.dart')));
      expect(text, isNot(contains('journal_repository_impl.dart')));
    }
  });
}
