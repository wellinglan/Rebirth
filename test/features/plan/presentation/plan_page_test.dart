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
import 'package:rebirth/features/plan/presentation/plan_filter_state.dart';
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
    expect(find.text('年度'), findsOneWidget);
    expect(find.text('进行中'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('planGoalCompleted_root-goal')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('planGoalStatusMenu_root-goal')),
      findsNothing,
    );
    expect(find.text('开始日期：2026-07-01'), findsOneWidget);
    expect(find.text('目标日期：2027-07-01'), findsOneWidget);
    expect(find.text('优先级：2'), findsOneWidget);
    expect(find.text('整理长期研究路线'), findsOneWidget);
    expect(find.text('子目标'), findsOneWidget);
    expect(find.text('添加子目标'), findsOneWidget);
  });

  testWidgets('filters are collapsed by default and the list stays visible', (
    tester,
  ) async {
    await _pumpPlanPage(tester, _FakePlanRepository(goals: [_rootGoal()]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('planFilterButton')), findsOneWidget);
    expect(find.byKey(const ValueKey('planFilterPanel')), findsNothing);
    expect(find.byKey(const ValueKey('planGoalList')), findsOneWidget);
    expect(find.text('年度研究方向'), findsOneWidget);
  });

  testWidgets('filter button opens and closes the responsive panel', (
    tester,
  ) async {
    await _pumpPlanPage(tester, _FakePlanRepository(goals: [_rootGoal()]));
    await tester.pumpAndSettle();

    await _openFilters(tester);

    expect(find.byKey(const ValueKey('planFilterBarrier')), findsOneWidget);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('planIncludeArchivedFilter')))
          .dy,
      greaterThan(
        tester.getBottomLeft(find.byKey(const ValueKey('planSortMode'))).dy,
      ),
    );

    await _closeFilters(tester);

    expect(find.byKey(const ValueKey('planFilterPanel')), findsNothing);
    expect(find.byKey(const ValueKey('planGoalList')), findsOneWidget);
  });

  testWidgets('tapping outside the panel closes it without hiding the list', (
    tester,
  ) async {
    await _pumpPlanPage(tester, _FakePlanRepository(goals: [_rootGoal()]));
    await tester.pumpAndSettle();
    await _openFilters(tester);

    final barrier = find.byKey(const ValueKey('planFilterBarrier'));
    final barrierRect = tester.getRect(barrier);
    await tester.tapAt(Offset(barrierRect.left + 8, barrierRect.bottom - 8));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('planFilterPanel')), findsNothing);
    expect(find.byKey(const ValueKey('planGoalList')), findsOneWidget);
  });

  testWidgets('tapping the header outside the panel closes it', (tester) async {
    await _pumpPlanPage(tester, _FakePlanRepository(goals: [_rootGoal()]));
    await tester.pumpAndSettle();
    await _openFilters(tester);

    await tester.tap(find.text('让今天与长期方向相连'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('planFilterPanel')), findsNothing);
    expect(find.byKey(const ValueKey('planGoalList')), findsOneWidget);
  });

  testWidgets('filter state survives closing and reopening the panel', (
    tester,
  ) async {
    await _pumpPlanPage(tester, _FakePlanRepository(goals: [_rootGoal()]));
    await tester.pumpAndSettle();
    await _openFilters(tester);

    tester
        .widget<DropdownButtonFormField<String>>(
          find.byKey(const ValueKey('planLevelFilter')),
        )
        .onChanged!('day');
    await tester.pumpAndSettle();

    expect(find.text('没有符合条件的目标。'), findsOneWidget);
    expect(find.byKey(const ValueKey('planFilterPanel')), findsOneWidget);

    await _closeFilters(tester);
    await _openFilters(tester);

    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('planLevelFilter')),
          )
          .initialValue,
      'day',
    );
    expect(find.text('没有符合条件的目标。'), findsOneWidget);
  });

  testWidgets('show archived toggles from the whole row and stays selected', (
    tester,
  ) async {
    final archived = _copyGoal(
      _rootGoal(id: 'archived-goal', title: '已归档研究'),
      archivedAt: 10,
    );
    await _pumpPlanPage(
      tester,
      _FakePlanRepository(goals: [_rootGoal(), archived]),
    );
    await tester.pumpAndSettle();
    await _openFilters(tester);

    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('planIncludeArchivedFilter')),
          )
          .value,
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('planIncludeArchivedFilter')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('planFilterPanel')), findsOneWidget);
    expect(find.text('已归档研究'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('planIncludeArchivedFilter')),
          )
          .value,
      isTrue,
    );

    await _closeFilters(tester);
    await _openFilters(tester);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('planIncludeArchivedFilter')),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('system back closes the filter panel before leaving Plan', (
    tester,
  ) async {
    await _pumpPlanPage(tester, _FakePlanRepository(goals: [_rootGoal()]));
    await tester.pumpAndSettle();
    await _openFilters(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('planFilterPanel')), findsNothing);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.byKey(const ValueKey('planGoalList')), findsOneWidget);
  });

  for (final width in [320.0, 360.0]) {
    testWidgets(
      '${width.toInt()}px with 2x text keeps filters scrollable and list reachable',
      (tester) async {
        await _pumpPlanPage(
          tester,
          _FakePlanRepository(goals: [_rootGoal()]),
          size: Size(width, 720),
          textScale: 2,
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('planGoalList')), findsOneWidget);
        await _openFilters(tester);
        expect(
          find.byKey(const ValueKey('planFilterPanelScroll')),
          findsOneWidget,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('planIncludeArchivedFilter')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('planIncludeArchivedFilter')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await _closeFilters(tester);
        expect(find.byKey(const ValueKey('planGoalList')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [720.0, 1200.0]) {
    testWidgets(
      '${width.toInt()}px Windows layout opens and closes filters without overflow',
      (tester) async {
        await _pumpPlanPage(
          tester,
          _FakePlanRepository(goals: [_rootGoal()]),
          size: Size(width, 900),
        );
        await tester.pumpAndSettle();

        await _openFilters(tester);
        expect(find.byKey(const ValueKey('planFilterPanel')), findsOneWidget);
        expect(tester.takeException(), isNull);

        await _closeFilters(tester);
        expect(find.byKey(const ValueKey('planGoalList')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

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

  testWidgets('completion checkbox updates the goal through the controller', (
    tester,
  ) async {
    final repository = _FakePlanRepository(goals: [_rootGoal()]);
    await _pumpPlanPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('planGoalCompleted_root-goal')));
    await tester.pumpAndSettle();

    expect(repository.lastCompleted, isTrue);
    expect(find.text('已完成'), findsOneWidget);
  });

  testWidgets(
    'completion failure shows a snackbar and keeps the current list',
    (tester) async {
      final repository = _FakePlanRepository(
        goals: [_rootGoal()],
        completionFailures: 1,
      );
      await _pumpPlanPage(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('planGoalCompleted_root-goal')),
      );
      await tester.pumpAndSettle();

      expect(find.text('完成状态更新失败，请重试'), findsOneWidget);
      expect(find.text('进行中'), findsOneWidget);
      expect(find.byKey(const ValueKey('planErrorState')), findsNothing);
    },
  );

  testWidgets('more menu archives and restores a goal', (tester) async {
    final repository = _FakePlanRepository(goals: [_rootGoal()]);
    await _pumpPlanPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('planGoalActionsMenu_root-goal')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('归档'));
    await tester.pumpAndSettle();
    expect(find.text('年度研究方向'), findsNothing);

    await _openFilters(tester);
    await tester.tap(find.byKey(const ValueKey('planIncludeArchivedFilter')));
    await tester.pumpAndSettle();
    expect(find.text('年度研究方向'), findsOneWidget);
    expect(find.text('已归档'), findsOneWidget);
    await _closeFilters(tester);

    await tester.tap(
      find.byKey(const ValueKey('planGoalActionsMenu_root-goal')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复归档'));
    await tester.pumpAndSettle();
    expect(repository.restoreCalls, 1);
  });

  testWidgets('delete requires confirmation before soft delete', (
    tester,
  ) async {
    final repository = _FakePlanRepository(goals: [_rootGoal()]);
    await _pumpPlanPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('planGoalActionsMenu_root-goal')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('deletePlanGoalConfirmationDialog')),
      findsOneWidget,
    );
    expect(repository.deleteCalls, 0);
    await tester.tap(find.byKey(const ValueKey('confirmDeletePlanGoalButton')));
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, 1);
    expect(find.text('年度研究方向'), findsNothing);
  });

  testWidgets('level and lifecycle filters show filtered empty state', (
    tester,
  ) async {
    final repository = _FakePlanRepository(goals: [_rootGoal()]);
    await _pumpPlanPage(tester, repository);
    await tester.pumpAndSettle();
    await _openFilters(tester);

    tester
        .widget<DropdownButtonFormField<String>>(
          find.byKey(const ValueKey('planLevelFilter')),
        )
        .onChanged!('day');
    await tester.pumpAndSettle();
    expect(find.text('没有符合条件的目标。'), findsOneWidget);

    tester
        .widget<DropdownButtonFormField<String>>(
          find.byKey(const ValueKey('planLevelFilter')),
        )
        .onChanged!('all');
    await tester.pumpAndSettle();
    expect(find.text('年度研究方向'), findsOneWidget);
  });

  testWidgets('lifecycle filter and every sort mode can be selected', (
    tester,
  ) async {
    final overdue = _rootGoal(
      id: 'overdue',
      title: '过期目标',
      level: PlanGoalLevel.month,
      startDate: '2026-06-01',
      targetDate: '2026-07-13',
      sortOrder: 5,
      createdAt: 1,
    );
    final future = _rootGoal(
      id: 'future',
      title: '未来目标',
      level: PlanGoalLevel.year,
      startDate: '2026-08-01',
      targetDate: '2027-08-01',
      sortOrder: 1,
      createdAt: 2,
    );
    await _pumpPlanPage(tester, _FakePlanRepository(goals: [overdue, future]));
    await tester.pumpAndSettle();
    await _openFilters(tester);

    tester
        .widget<DropdownButtonFormField<PlanLifecycleFilter>>(
          find.byKey(const ValueKey('planLifecycleFilter')),
        )
        .onChanged!(PlanLifecycleFilter.overdue);
    await tester.pumpAndSettle();
    expect(find.text('过期目标'), findsOneWidget);
    expect(find.text('未来目标'), findsNothing);

    tester
        .widget<DropdownButtonFormField<PlanLifecycleFilter>>(
          find.byKey(const ValueKey('planLifecycleFilter')),
        )
        .onChanged!(PlanLifecycleFilter.all);
    await tester.pumpAndSettle();
    final sortField = tester.widget<DropdownButtonFormField<PlanSortMode>>(
      find.byKey(const ValueKey('planSortMode')),
    );
    for (final mode in PlanSortMode.values) {
      sortField.onChanged!(mode);
      await tester.pumpAndSettle();
      expect(find.text('过期目标'), findsOneWidget);
      expect(find.text('未来目标'), findsOneWidget);
    }
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
      'lib/features/plan/presentation/plan_filter_state.dart',
      'lib/features/plan/presentation/widgets/plan_date_parts_field.dart',
      'lib/features/plan/presentation/widgets/plan_filter_panel.dart',
      'lib/features/plan/presentation/widgets/plan_goal_actions_menu.dart',
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
  PlanRepository repository, {
  Size size = const Size(1000, 1000),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        planRepositoryProvider.overrideWithValue(repository),
        dateTimeServiceProvider.overrideWithValue(
          DateTimeService(now: () => DateTime(2026, 7, 14, 10)),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: PlanPage()),
      ),
    ),
  );
}

Future<void> _openFilters(WidgetTester tester) async {
  expect(find.byKey(const ValueKey('planFilterPanel')), findsNothing);
  await tester.tap(find.byKey(const ValueKey('planFilterButton')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('planFilterPanel')), findsOneWidget);
}

Future<void> _closeFilters(WidgetTester tester) async {
  expect(find.byKey(const ValueKey('planFilterPanel')), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('planFilterButton')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('planFilterPanel')), findsNothing);
}

Future<void> _submitForm(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('submitPlanGoalButton'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

PlanGoal _rootGoal({
  String id = 'root-goal',
  String title = '年度研究方向',
  PlanGoalLevel level = PlanGoalLevel.year,
  String? startDate = '2026-07-01',
  String? targetDate = '2027-07-01',
  int sortOrder = 2,
  int createdAt = 1,
}) {
  return PlanGoal(
    id: id,
    userId: 'user-id',
    parentGoalId: null,
    title: title,
    description: '整理长期研究路线',
    goalLevel: level,
    status: PlanGoalStatus.inProgress,
    startDate: startDate,
    targetDate: targetDate,
    completedAt: null,
    sortOrder: sortOrder,
    createdAt: createdAt,
    updatedAt: 1,
  );
}

final class _FakePlanRepository implements PlanRepository {
  _FakePlanRepository({
    List<PlanGoal> goals = const [],
    this.loadGate,
    this.loadError,
    this.createFailures = 0,
    this.completionFailures = 0,
  }) : goals = List.of(goals);

  List<PlanGoal> goals;
  final Completer<List<PlanGoal>>? loadGate;
  Object? loadError;
  int createFailures;
  int completionFailures;
  int listRootCalls = 0;
  int createAttempts = 0;
  PlanGoalSaveData? lastCreated;
  bool? lastCompleted;
  int restoreCalls = 0;
  int deleteCalls = 0;

  @override
  Future<List<PlanGoal>> listRootGoals({bool includeArchived = false}) async {
    listRootCalls += 1;
    if (loadError != null) {
      throw loadError!;
    }
    if (loadGate != null) {
      return loadGate!.future;
    }
    return goals
        .where(
          (goal) =>
              goal.parentGoalId == null &&
              (includeArchived || goal.archivedAt == null),
        )
        .toList();
  }

  @override
  Future<List<PlanGoal>> listChildren(
    String parentGoalId, {
    bool includeArchived = false,
  }) async {
    if (loadError != null) {
      throw loadError!;
    }
    return goals
        .where(
          (goal) =>
              goal.parentGoalId == parentGoalId &&
              (includeArchived || goal.archivedAt == null),
        )
        .toList();
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
    return _setStatus(id, status);
  }

  @override
  Future<PlanGoal> updateCompletion({
    required String id,
    required bool completed,
  }) async {
    if (completionFailures > 0) {
      completionFailures -= 1;
      throw StateError('completion failed for test');
    }
    lastCompleted = completed;
    return _setStatus(
      id,
      completed ? PlanGoalStatus.completed : PlanGoalStatus.inProgress,
    );
  }

  PlanGoal _setStatus(String id, PlanGoalStatus status) {
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
  Future<void> archiveGoal(String id) async {
    final index = goals.indexWhere((goal) => goal.id == id);
    goals[index] = _copyGoal(goals[index], archivedAt: 10);
  }

  @override
  Future<void> restoreGoal(String id) async {
    restoreCalls += 1;
    final index = goals.indexWhere((goal) => goal.id == id);
    goals[index] = _copyGoal(goals[index], clearArchivedAt: true);
  }

  @override
  Future<void> softDelete(String id) async {
    deleteCalls += 1;
    goals.removeWhere((goal) => goal.id == id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PlanGoal _copyGoal(
  PlanGoal goal, {
  int? archivedAt,
  bool clearArchivedAt = false,
}) {
  return PlanGoal(
    id: goal.id,
    userId: goal.userId,
    parentGoalId: goal.parentGoalId,
    title: goal.title,
    description: goal.description,
    goalLevel: goal.goalLevel,
    status: goal.status,
    startDate: goal.startDate,
    targetDate: goal.targetDate,
    completedAt: goal.completedAt,
    archivedAt: clearArchivedAt ? null : archivedAt ?? goal.archivedAt,
    sortOrder: goal.sortOrder,
    createdAt: goal.createdAt,
    updatedAt: goal.updatedAt + 1,
  );
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
