import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/plan/data/plan_repository_provider.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_repository.dart';
import 'package:rebirth/features/plan/presentation/plan_page.dart';

void main() {
  testWidgets('PlanPage shows loading', (tester) async {
    final gate = Completer<List<PlanGoal>>();
    await _pumpPlanPage(tester, _FakePlanRepository(loadGate: gate));

    expect(find.byKey(const ValueKey('planLoadingState')), findsOneWidget);
  });

  testWidgets('PlanPage shows an error and retries', (tester) async {
    final repository = _FakePlanRepository(
      loadError: StateError('load failed for test'),
    );
    await _pumpPlanPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('planErrorState')), findsOneWidget);
    expect(find.text('计划暂时无法加载'), findsOneWidget);

    repository.loadError = null;
    await tester.tap(find.byTooltip('重新加载'));
    await tester.pumpAndSettle();

    expect(repository.listRootCalls, 2);
    expect(find.byKey(const ValueKey('planEmptyState')), findsOneWidget);
  });

  testWidgets('PlanPage shows the empty state', (tester) async {
    await _pumpPlanPage(tester, _FakePlanRepository());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('planEmptyState')), findsOneWidget);
    expect(find.text('还没有计划，先写下一个阶段目标。'), findsOneWidget);
  });

  testWidgets('PlanPage displays title, level, status, and target date', (
    tester,
  ) async {
    await _pumpPlanPage(tester, _FakePlanRepository(goals: [_sampleGoal()]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('planGoalList')), findsOneWidget);
    expect(find.text('共 1 个目标'), findsOneWidget);
    expect(find.text('完成论文初稿'), findsOneWidget);
    expect(find.text('季度 · 进行中'), findsOneWidget);
    expect(find.text('目标日期：2026-09-30'), findsOneWidget);
  });

  test('Plan presentation has no database implementation imports', () {
    const paths = <String>[
      'lib/features/plan/presentation/plan_page.dart',
      'lib/features/plan/presentation/plan_controller.dart',
    ];

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('package:drift')));
      expect(source, isNot(contains('app_database.dart')));
      expect(source, isNot(contains('plan_repository_impl.dart')));
      expect(source, isNot(contains('DateTime.now()')));
    }
  });
}

Future<void> _pumpPlanPage(
  WidgetTester tester,
  PlanRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [planRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: Scaffold(body: PlanPage())),
    ),
  );
}

PlanGoal _sampleGoal() {
  return const PlanGoal(
    id: 'goal-id',
    userId: 'user-id',
    parentGoalId: null,
    title: '完成论文初稿',
    description: '整理核心实验结果',
    goalLevel: PlanGoalLevel.quarter,
    status: PlanGoalStatus.inProgress,
    startDate: '2026-07-01',
    targetDate: '2026-09-30',
    completedAt: null,
    sortOrder: 0,
    createdAt: 1,
    updatedAt: 1,
  );
}

final class _FakePlanRepository implements PlanRepository {
  _FakePlanRepository({this.goals = const [], this.loadGate, this.loadError});

  final List<PlanGoal> goals;
  final Completer<List<PlanGoal>>? loadGate;
  Object? loadError;
  int listRootCalls = 0;

  @override
  Future<List<PlanGoal>> listRootGoals() async {
    listRootCalls += 1;
    if (loadError != null) {
      throw loadError!;
    }
    return loadGate?.future ?? goals;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
