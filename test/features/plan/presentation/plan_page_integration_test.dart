import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/plan/data/plan_repository_provider.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/presentation/plan_page.dart';

void main() {
  testWidgets('UI creates, edits, and completes a persisted root goal', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        dateTimeServiceProvider.overrideWithValue(
          DateTimeService(now: () => DateTime(2026, 7, 14, 10)),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: PlanPage())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('newPlanGoalButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('planGoalTitleField')),
      '真实持久化目标',
    );
    await tester.tap(find.byKey(const ValueKey('submitPlanGoalButton')));
    await tester.pumpAndSettle();

    var goals = await container.read(planRepositoryProvider).listRootGoals();
    expect(goals, hasLength(1));
    expect(goals.single.title, '真实持久化目标');
    expect(goals.single.parentGoalId, isNull);

    final goalId = goals.single.id;
    await tester.tap(find.byKey(ValueKey('planGoalItem_$goalId')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('planGoalTitleField')),
      '已编辑的真实目标',
    );
    await tester.tap(find.byKey(const ValueKey('submitPlanGoalButton')));
    await tester.pumpAndSettle();

    goals = await container.read(planRepositoryProvider).listRootGoals();
    expect(goals.single.id, goalId);
    expect(goals.single.title, '已编辑的真实目标');

    await tester.tap(find.byKey(ValueKey('planGoalStatusMenu_$goalId')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<PlanGoalStatus>, '已完成'),
    );
    await tester.pumpAndSettle();

    final completed = await container
        .read(planRepositoryProvider)
        .getById(goalId);
    expect(completed?.status, PlanGoalStatus.completed);
    expect(completed?.completedAt, isNotNull);
    expect(database.schemaVersion, 2);
  });
}
