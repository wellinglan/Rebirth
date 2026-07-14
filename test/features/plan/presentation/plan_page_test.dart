import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/plan/data/plan_repository_provider.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_goal_save_data.dart';
import 'package:rebirth/features/plan/domain/plan_repository.dart';
import 'package:rebirth/features/plan/presentation/plan_page.dart';

void main() {
  testWidgets('PlanPage shows its header and loading state', (tester) async {
    final gate = Completer<List<PlanGoal>>();
    await _pumpPlanPage(tester, _FakePlanRepository(loadGate: gate));

    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('让今天与长期方向相连'), findsOneWidget);
    expect(find.byKey(const ValueKey('newPlanGoalButton')), findsOneWidget);
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

  testWidgets('empty state can open the create form', (tester) async {
    await _pumpPlanPage(tester, _FakePlanRepository());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('planEmptyState')), findsOneWidget);
    expect(find.text('还没有计划，先写下一个阶段目标。'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('emptyNewPlanGoalButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('planGoalFormDialog')), findsOneWidget);
    expect(find.text('新建目标'), findsWidgets);
    expect(_fieldText(tester, 'planGoalSortOrderField'), '0');
  });

  testWidgets('blank title shows validation without creating', (tester) async {
    final repository = _FakePlanRepository();
    await _pumpPlanPage(tester, repository);
    await tester.pumpAndSettle();
    await _openCreateForm(tester);

    await _submitForm(tester);

    expect(find.text('目标标题不能为空'), findsOneWidget);
    expect(repository.createAttempts, 0);
    expect(find.byKey(const ValueKey('planGoalFormDialog')), findsOneWidget);
  });

  testWidgets('invalid dates and negative sort order show field errors', (
    tester,
  ) async {
    final repository = _FakePlanRepository();
    await _pumpPlanPage(tester, repository);
    await tester.pumpAndSettle();
    await _openCreateForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('planGoalTitleField')),
      '校验目标',
    );
    await tester.enterText(
      find.byKey(const ValueKey('planGoalStartDateField')),
      '2026/07/14',
    );
    await tester.enterText(
      find.byKey(const ValueKey('planGoalTargetDateField')),
      '2026-02-30',
    );
    await tester.enterText(
      find.byKey(const ValueKey('planGoalSortOrderField')),
      '-1',
    );

    await _submitForm(tester);

    expect(find.text('请输入 YYYY-MM-DD 格式日期'), findsNWidgets(2));
    expect(find.text('请输入非负整数'), findsOneWidget);
    expect(repository.createAttempts, 0);
  });

  testWidgets('target date before start date is rejected', (tester) async {
    final repository = _FakePlanRepository();
    await _pumpPlanPage(tester, repository);
    await tester.pumpAndSettle();
    await _openCreateForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('planGoalTitleField')),
      '日期范围目标',
    );
    await tester.enterText(
      find.byKey(const ValueKey('planGoalStartDateField')),
      '2026-07-14',
    );
    await tester.enterText(
      find.byKey(const ValueKey('planGoalTargetDateField')),
      '2026-07-13',
    );

    await _submitForm(tester);

    expect(find.text('目标日期不能早于开始日期'), findsOneWidget);
    expect(repository.createAttempts, 0);
  });

  testWidgets('valid input creates a root goal and closes the dialog', (
    tester,
  ) async {
    final repository = _FakePlanRepository();
    await _pumpPlanPage(tester, repository);
    await tester.pumpAndSettle();
    await _openCreateForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('planGoalTitleField')),
      '  完成论文初稿  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('planGoalDescriptionField')),
      '   ',
    );
    await tester.tap(find.byKey(const ValueKey('planGoalLevelField')));
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getCenter(
        find.widgetWithText(DropdownMenuItem<PlanGoalLevel>, '年度').last,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('planGoalStatusField')));
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getCenter(
        find.widgetWithText(DropdownMenuItem<PlanGoalStatus>, '进行中').last,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('planGoalTargetDateField')),
      '2026-09-30',
    );
    await tester.enterText(
      find.byKey(const ValueKey('planGoalSortOrderField')),
      '3',
    );

    await _submitForm(tester);

    expect(find.byKey(const ValueKey('planGoalFormDialog')), findsNothing);
    expect(repository.createAttempts, 1);
    expect(repository.lastCreated?.parentGoalId, isNull);
    expect(repository.lastCreated?.title, '完成论文初稿');
    expect(repository.lastCreated?.description, isNull);
    expect(repository.lastCreated?.goalLevel, PlanGoalLevel.year);
    expect(repository.lastCreated?.status, PlanGoalStatus.inProgress);
    expect(repository.lastCreated?.targetDate, '2026-09-30');
    expect(repository.lastCreated?.sortOrder, 3);
    expect(find.text('完成论文初稿'), findsOneWidget);
  });

  testWidgets('saving disables submit and keeps the form visible', (
    tester,
  ) async {
    final saveGate = Completer<void>();
    final repository = _FakePlanRepository(createGate: saveGate);
    await _pumpPlanPage(tester, repository);
    await tester.pumpAndSettle();
    await _openCreateForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('planGoalTitleField')),
      '保存中的目标',
    );

    final button = find.byKey(const ValueKey('submitPlanGoalButton'));
    await tester.tap(button);
    await tester.pump();

    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.text('保存中...'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('planGoalSaveProgressIndicator')),
      findsOneWidget,
    );
    expect(_fieldText(tester, 'planGoalTitleField'), '保存中的目标');
    expect(repository.createAttempts, 1);

    saveGate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('create failure keeps dialog input and existing list state', (
    tester,
  ) async {
    final existing = _sampleGoal();
    final repository = _FakePlanRepository(
      goals: [existing],
      createFailures: 1,
    );
    await _pumpPlanPage(tester, repository);
    await tester.pumpAndSettle();
    await _openCreateForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('planGoalTitleField')),
      '失败后保留',
    );

    await _submitForm(tester);

    expect(find.text('创建失败，请重试'), findsOneWidget);
    expect(find.byKey(const ValueKey('planGoalFormDialog')), findsOneWidget);
    expect(_fieldText(tester, 'planGoalTitleField'), '失败后保留');
    expect(find.byKey(const ValueKey('planErrorState')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('cancelPlanGoalButton')));
    await tester.pumpAndSettle();
    expect(find.text(existing.title), findsOneWidget);
  });

  testWidgets('data state displays goal metadata and description', (
    tester,
  ) async {
    await _pumpPlanPage(tester, _FakePlanRepository(goals: [_sampleGoal()]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('planGoalList')), findsOneWidget);
    expect(find.text('共 1 个目标'), findsOneWidget);
    expect(find.text('完成论文初稿'), findsOneWidget);
    expect(find.text('季度 · 进行中'), findsOneWidget);
    expect(find.text('目标日期：2026-09-30'), findsOneWidget);
    expect(find.text('整理核心实验结果'), findsOneWidget);
  });

  testWidgets('tapping a goal opens an edit form with existing values', (
    tester,
  ) async {
    await _pumpPlanPage(tester, _FakePlanRepository(goals: [_sampleGoal()]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('planGoalItem_goal-id')));
    await tester.pumpAndSettle();

    expect(find.text('编辑目标'), findsOneWidget);
    expect(_fieldText(tester, 'planGoalTitleField'), '完成论文初稿');
    expect(_fieldText(tester, 'planGoalDescriptionField'), '整理核心实验结果');
    expect(_fieldText(tester, 'planGoalStartDateField'), '2026-07-01');
    expect(_fieldText(tester, 'planGoalTargetDateField'), '2026-09-30');
    expect(_fieldText(tester, 'planGoalSortOrderField'), '2');
    expect(find.text('季度'), findsOneWidget);
    expect(find.text('进行中'), findsOneWidget);
    expect(find.text('保存修改'), findsOneWidget);
  });

  testWidgets('editing updates the goal and closes the dialog', (tester) async {
    final repository = _FakePlanRepository(goals: [_sampleGoal()]);
    await _pumpPlanPage(tester, repository);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('planGoalItem_goal-id')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('planGoalTitleField')),
      '修改后的标题',
    );

    await _submitForm(tester);

    expect(repository.updateAttempts, 1);
    expect(find.byKey(const ValueKey('planGoalFormDialog')), findsNothing);
    expect(find.text('修改后的标题'), findsOneWidget);
  });

  testWidgets('edit failure keeps modified input', (tester) async {
    final repository = _FakePlanRepository(
      goals: [_sampleGoal()],
      updateFailures: 1,
    );
    await _pumpPlanPage(tester, repository);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('planGoalItem_goal-id')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('planGoalTitleField')),
      '编辑失败后保留',
    );

    await _submitForm(tester);

    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(find.byKey(const ValueKey('planGoalFormDialog')), findsOneWidget);
    expect(_fieldText(tester, 'planGoalTitleField'), '编辑失败后保留');
    expect(find.byKey(const ValueKey('planErrorState')), findsNothing);
  });

  testWidgets('status menu updates status through the controller', (
    tester,
  ) async {
    final repository = _FakePlanRepository(goals: [_sampleGoal()]);
    await _pumpPlanPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('planGoalStatusMenu_goal-id')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<PlanGoalStatus>, '已完成'),
    );
    await tester.pumpAndSettle();

    expect(repository.lastStatus, PlanGoalStatus.completed);
    expect(find.text('季度 · 已完成'), findsOneWidget);
  });

  testWidgets('status failure shows a snackbar and keeps the list', (
    tester,
  ) async {
    final repository = _FakePlanRepository(
      goals: [_sampleGoal()],
      statusFailures: 1,
    );
    await _pumpPlanPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('planGoalStatusMenu_goal-id')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<PlanGoalStatus>, '已完成'),
    );
    await tester.pumpAndSettle();

    expect(find.text('状态更新失败，请重试'), findsOneWidget);
    expect(find.text('季度 · 进行中'), findsOneWidget);
    expect(find.byKey(const ValueKey('planErrorState')), findsNothing);
  });

  test('Plan presentation has no database implementation imports', () {
    const paths = <String>[
      'lib/features/plan/presentation/plan_page.dart',
      'lib/features/plan/presentation/plan_controller.dart',
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
  await tester.binding.setSurfaceSize(const Size(1000, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [planRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: Scaffold(body: PlanPage())),
    ),
  );
}

Future<void> _openCreateForm(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('newPlanGoalButton')));
  await tester.pumpAndSettle();
}

Future<void> _submitForm(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('submitPlanGoalButton'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, String key) {
  return tester
      .widget<TextFormField>(find.byKey(ValueKey(key)))
      .controller!
      .text;
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
    this.createGate,
    this.createFailures = 0,
    this.updateFailures = 0,
    this.statusFailures = 0,
  }) : goals = List.of(goals);

  List<PlanGoal> goals;
  final Completer<List<PlanGoal>>? loadGate;
  Object? loadError;
  final Completer<void>? createGate;
  int createFailures;
  int updateFailures;
  int statusFailures;
  int listRootCalls = 0;
  int createAttempts = 0;
  int updateAttempts = 0;
  PlanGoalSaveData? lastCreated;
  PlanGoalStatus? lastStatus;

  @override
  Future<List<PlanGoal>> listRootGoals() async {
    listRootCalls += 1;
    if (loadError != null) {
      throw loadError!;
    }
    return loadGate?.future ?? List.unmodifiable(goals);
  }

  @override
  Future<PlanGoal> createGoal(PlanGoalSaveData data) async {
    createAttempts += 1;
    if (createFailures > 0) {
      createFailures -= 1;
      throw StateError('create failed for test');
    }
    await createGate?.future;
    lastCreated = data;
    final goal = _goalFromData(id: 'created-goal', data: data);
    goals = [...goals, goal];
    return goal;
  }

  @override
  Future<PlanGoal> updateGoal({
    required String id,
    required PlanGoalSaveData data,
  }) async {
    updateAttempts += 1;
    if (updateFailures > 0) {
      updateFailures -= 1;
      throw StateError('update failed for test');
    }
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
    final existing = goals.singleWhere((goal) => goal.id == id);
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
    goals = [updated];
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
