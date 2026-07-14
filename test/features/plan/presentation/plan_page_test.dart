import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/plan/data/plan_repository_provider.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_goal_save_data.dart';
import 'package:rebirth/features/plan/domain/plan_repository.dart';
import 'package:rebirth/features/plan/presentation/plan_page.dart';
import 'package:rebirth/features/plan/presentation/widgets/plan_goal_form_dialog.dart';

void main() {
  testWidgets('root view shows header, create button, and loading state', (
    tester,
  ) async {
    final gate = Completer<List<PlanGoal>>();
    await _pumpPlanPage(tester, _FakePlanRepository(loadGate: gate));

    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('让今天与长期方向相连'), findsOneWidget);
    expect(find.text('新建目标'), findsOneWidget);
    expect(find.byKey(const ValueKey('planLoadingState')), findsOneWidget);
  });

  testWidgets('load error shows retry and recovers to root empty state', (
    tester,
  ) async {
    final repository = _FakePlanRepository(
      loadError: StateError('load failed for test'),
    );
    await _pumpPlanPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('planErrorState')), findsOneWidget);
    repository.loadError = null;
    await tester.tap(find.byTooltip('重新加载'));
    await tester.pumpAndSettle();

    expect(repository.listRootCalls, 2);
    expect(find.text('还没有计划，先写下一个阶段目标。'), findsOneWidget);
  });

  testWidgets('root goal card shows metadata and child actions', (
    tester,
  ) async {
    await _pumpPlanPage(tester, _FakePlanRepository(goals: [_rootGoal()]));
    await tester.pumpAndSettle();

    expect(find.text('年度研究方向'), findsOneWidget);
    expect(find.text('年度 · 进行中'), findsOneWidget);
    expect(find.text('开始日期：2026-07-01'), findsOneWidget);
    expect(find.text('目标日期：2027-07-01'), findsOneWidget);
    expect(find.text('优先级：2'), findsOneWidget);
    expect(find.text('整理长期研究路线'), findsOneWidget);
    expect(find.text('子目标'), findsOneWidget);
    expect(find.text('添加子目标'), findsOneWidget);
  });

  testWidgets('child action enters child view and back returns to root', (
    tester,
  ) async {
    final repository = _FakePlanRepository(goals: [_rootGoal()]);
    await _pumpPlanPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('viewPlanGoalChildren_root-goal')),
    );
    await tester.pumpAndSettle();

    expect(find.text('年度研究方向'), findsWidgets);
    expect(find.text('这个目标还没有子目标。'), findsOneWidget);
    expect(find.text('新建子目标'), findsWidgets);
    expect(find.byKey(const ValueKey('planBackButton')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('planRootBreadcrumbButton')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('planBackButton')));
    await tester.pumpAndSettle();

    expect(find.text('让今天与长期方向相连'), findsOneWidget);
    expect(find.text('新建目标'), findsOneWidget);
    expect(find.text('年度研究方向'), findsOneWidget);
  });

  testWidgets('direct add child creates with card parent and lower level', (
    tester,
  ) async {
    final repository = _FakePlanRepository(goals: [_rootGoal()]);
    await _pumpPlanPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('addPlanGoalChild_root-goal')));
    await tester.pumpAndSettle();
    final dialog = tester.widget<PlanGoalFormDialog>(
      find.byType(PlanGoalFormDialog),
    );
    expect(dialog.parentGoalId, 'root-goal');
    expect(dialog.defaultGoalLevel, PlanGoalLevel.quarter);
    await tester.enterText(
      find.byKey(const ValueKey('planGoalTitleField')),
      '第一季度实验',
    );

    await _submitForm(tester);

    expect(repository.lastCreated?.parentGoalId, 'root-goal');
    expect(repository.lastCreated?.goalLevel, PlanGoalLevel.quarter);
  });

  testWidgets('child view create button uses the current parent', (
    tester,
  ) async {
    final repository = _FakePlanRepository(goals: [_rootGoal()]);
    await _pumpPlanPage(tester, repository);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('viewPlanGoalChildren_root-goal')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('newPlanGoalButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('planGoalTitleField')),
      '当前层级子目标',
    );
    await _submitForm(tester);

    expect(repository.lastCreated?.parentGoalId, 'root-goal');
  });

  testWidgets('status menu updates the goal through the controller', (
    tester,
  ) async {
    final repository = _FakePlanRepository(goals: [_rootGoal()]);
    await _pumpPlanPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('planGoalStatusMenu_root-goal')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<PlanGoalStatus>, '已完成'),
    );
    await tester.pumpAndSettle();

    expect(repository.lastStatus, PlanGoalStatus.completed);
    expect(find.text('年度 · 已完成'), findsOneWidget);
  });

  testWidgets('status failure shows a snackbar and keeps the current list', (
    tester,
  ) async {
    final repository = _FakePlanRepository(
      goals: [_rootGoal()],
      statusFailures: 1,
    );
    await _pumpPlanPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('planGoalStatusMenu_root-goal')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<PlanGoalStatus>, '已完成'),
    );
    await tester.pumpAndSettle();

    expect(find.text('状态更新失败，请重试'), findsOneWidget);
    expect(find.text('年度 · 进行中'), findsOneWidget);
    expect(find.byKey(const ValueKey('planErrorState')), findsNothing);
  });

  testWidgets('create failure preserves dialog input and root list', (
    tester,
  ) async {
    final repository = _FakePlanRepository(
      goals: [_rootGoal()],
      createFailures: 1,
    );
    await _pumpPlanPage(tester, repository);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('newPlanGoalButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('planGoalTitleField')),
      '失败后保留',
    );

    await _submitForm(tester);

    expect(find.text('创建失败，请重试'), findsOneWidget);
    expect(find.text('失败后保留'), findsOneWidget);
    expect(find.byKey(const ValueKey('planGoalFormDialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cancelPlanGoalButton')));
    await tester.pumpAndSettle();
    expect(find.text('年度研究方向'), findsOneWidget);
  });

  test('Plan presentation has no database implementation imports', () {
    const paths = <String>[
      'lib/features/plan/presentation/plan_page.dart',
      'lib/features/plan/presentation/plan_controller.dart',
      'lib/features/plan/presentation/plan_view_state.dart',
      'lib/features/plan/presentation/widgets/plan_date_parts_field.dart',
      'lib/features/plan/presentation/widgets/plan_goal_form_dialog.dart',
      'lib/features/plan/presentation/widgets/plan_goal_card.dart',
      'lib/features/plan/presentation/widgets/plan_goal_status_menu.dart',
      'lib/features/plan/presentation/widgets/plan_goal_labels.dart',
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
  await tester.binding.setSurfaceSize(const Size(1000, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        planRepositoryProvider.overrideWithValue(repository),
        dateTimeServiceProvider.overrideWithValue(
          DateTimeService(now: () => DateTime(2026, 7, 14, 10)),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: PlanPage())),
    ),
  );
}

Future<void> _submitForm(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('submitPlanGoalButton'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

PlanGoal _rootGoal() {
  return const PlanGoal(
    id: 'root-goal',
    userId: 'user-id',
    parentGoalId: null,
    title: '年度研究方向',
    description: '整理长期研究路线',
    goalLevel: PlanGoalLevel.year,
    status: PlanGoalStatus.inProgress,
    startDate: '2026-07-01',
    targetDate: '2027-07-01',
    completedAt: null,
    sortOrder: 2,
    createdAt: 1,
    updatedAt: 1,
  );
}

final class _FakePlanRepository implements PlanRepository {
  _FakePlanRepository({
    List<PlanGoal> goals = const [],
    this.loadGate,
    this.loadError,
    this.createFailures = 0,
    this.statusFailures = 0,
  }) : goals = List.of(goals);

  List<PlanGoal> goals;
  final Completer<List<PlanGoal>>? loadGate;
  Object? loadError;
  int createFailures;
  int statusFailures;
  int listRootCalls = 0;
  int createAttempts = 0;
  PlanGoalSaveData? lastCreated;
  PlanGoalStatus? lastStatus;

  @override
  Future<List<PlanGoal>> listRootGoals() async {
    listRootCalls += 1;
    if (loadError != null) {
      throw loadError!;
    }
    if (loadGate != null) {
      return loadGate!.future;
    }
    return goals.where((goal) => goal.parentGoalId == null).toList();
  }

  @override
  Future<List<PlanGoal>> listChildren(String parentGoalId) async {
    if (loadError != null) {
      throw loadError!;
    }
    return goals.where((goal) => goal.parentGoalId == parentGoalId).toList();
  }

  @override
  Future<PlanGoal> createGoal(PlanGoalSaveData data) async {
    createAttempts += 1;
    if (createFailures > 0) {
      createFailures -= 1;
      throw StateError('create failed for test');
    }
    lastCreated = data;
    final goal = _goalFromData(id: 'created-$createAttempts', data: data);
    goals = [...goals, goal];
    return goal;
  }

  @override
  Future<PlanGoal> updateGoal({
    required String id,
    required PlanGoalSaveData data,
  }) async {
    final updated = _goalFromData(id: id, data: data);
    goals = goals.map((goal) => goal.id == id ? updated : goal).toList();
    return updated;
  }

  @override
  Future<PlanGoal> updateStatus({
    required String id,
    required PlanGoalStatus status,
  }) async {
    if (statusFailures > 0) {
      statusFailures -= 1;
      throw StateError('status failed for test');
    }
    lastStatus = status;
    final index = goals.indexWhere((goal) => goal.id == id);
    final existing = goals[index];
    final updated = PlanGoal(
      id: existing.id,
      userId: existing.userId,
      parentGoalId: existing.parentGoalId,
      title: existing.title,
      description: existing.description,
      goalLevel: existing.goalLevel,
      status: status,
      startDate: existing.startDate,
      targetDate: existing.targetDate,
      completedAt: status == PlanGoalStatus.completed ? 2 : null,
      sortOrder: existing.sortOrder,
      createdAt: existing.createdAt,
      updatedAt: existing.updatedAt + 1,
    );
    goals[index] = updated;
    return updated;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PlanGoal _goalFromData({required String id, required PlanGoalSaveData data}) {
  return PlanGoal(
    id: id,
    userId: 'user-id',
    parentGoalId: data.parentGoalId,
    title: data.title,
    description: data.description,
    goalLevel: data.goalLevel,
    status: data.status,
    startDate: data.startDate,
    targetDate: data.targetDate,
    completedAt: data.status == PlanGoalStatus.completed ? 2 : null,
    sortOrder: data.sortOrder,
    createdAt: 1,
    updatedAt: 2,
  );
}
