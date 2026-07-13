import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/app/rebirth_app.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';

void main() {
  testWidgets('renders Today state and switches destinations', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          dateTimeServiceProvider.overrideWithValue(
            DateTimeService(now: () => DateTime(2026, 7, 10, 9)),
          ),
        ],
        child: const RebirthApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2026-07-10'), findsOneWidget);
    expect(find.byKey(const ValueKey('todayEmptyState')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.auto_stories_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.auto_stories), findsOneWidget);
    expect(find.byKey(const ValueKey('journalEmptyState')), findsOneWidget);
  });
}
