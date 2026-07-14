import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/plan/data/plan_repository_provider.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_goal_save_data.dart';
import 'package:rebirth/features/plan/domain/plan_repository.dart';
import 'package:rebirth/features/plan/presentation/plan_controller.dart';
import 'package:rebirth/features/plan/presentation/plan_filter_state.dart';
import 'package:rebirth/features/plan/presentation/plan_view_state.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        dateTimeServiceProvider.overrideWithValue(
          DateTimeService(now: () => DateTime(2026, 7, 14, 10)),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('initially loads an empty root view', () async {
    expect(
      container.read(planControllerProvider),
      isA<AsyncLoading<PlanViewState>>(),
    );

    final view = await container.read(planControllerProvider.future);
    expect(view.goals, isEmpty);
    expect(view.breadcrumbs, isEmpty);
    expect(view.isRoot, isTrue);
  });

  test('createGoal at root creates a root goal and refreshes', () async {
    await container.read(planControllerProvider.future);

    await container
        .read(planControllerProvider.notifier)
        .createGoal(
          PlanGoalSaveData(title: '年度研究方向', goalLevel: PlanGoalLevel.year),
        );

    final view = container.read(planControllerProvider).requireValue;
    expect(view.goals, hasLength(1));
    expect(view.goals.single.title, '年度研究方向');
    expect(view.goals.single.parentGoalId, isNull);
  });

  test('openChildren and createGoal attach the current parent', () async {
    final repository = container.read(planRepositoryProvider);
    final parent = await repository.createGoal(
      PlanGoalSaveData(title: '年度目标', goalLevel: PlanGoalLevel.year),
    );
    await container.read(planControllerProvider.future);
    final controller = container.read(planControllerProvider.notifier);

    await controller.openChildren(parent);
    expect(
      container.read(planControllerProvider).requireValue.currentParent,
      parent,
    );

    await controller.createGoal(
      PlanGoalSaveData(title: '季度子目标', goalLevel: PlanGoalLevel.quarter),
    );

    final view = container.read(planControllerProvider).requireValue;
    expect(view.goals, hasLength(1));
    expect(view.goals.single.parentGoalId, parent.id);
    expect(view.goals.single.title, '季度子目标');
  });

  test('back and breadcrumb navigation restore the expected level', () async {
    final repository = container.read(planRepositoryProvider);
    final root = await repository.createGoal(
      PlanGoalSaveData(title: '人生方向', goalLevel: PlanGoalLevel.life),
    );
    final child = await repository.createGoal(
      PlanGoalSaveData(
        parentGoalId: root.id,
        title: '年度目标',
        goalLevel: PlanGoalLevel.year,
      ),
    );
    await repository.createGoal(
      PlanGoalSaveData(
        parentGoalId: child.id,
        title: '季度目标',
        goalLevel: PlanGoalLevel.quarter,
      ),
    );
    await container.read(planControllerProvider.future);
    final controller = container.read(planControllerProvider.notifier);

    await controller.openChildren(root);
    await controller.openChildren(child);
    var view = container.read(planControllerProvider).requireValue;
    expect(view.breadcrumbs, [root, child]);
    expect(view.goals.single.title, '季度目标');

    await controller.navigateToBreadcrumb(0);
    view = container.read(planControllerProvider).requireValue;
    expect(view.breadcrumbs, [root]);
    expect(view.goals.single.id, child.id);

    await controller.navigateBack();
    view = container.read(planControllerProvider).requireValue;
    expect(view.isRoot, isTrue);
    expect(view.goals.single.id, root.id);
  });

  test('updateCompletion refreshes the current child list', () async {
    final repository = container.read(planRepositoryProvider);
    final parent = await repository.createGoal(
      PlanGoalSaveData(title: '父目标', goalLevel: PlanGoalLevel.year),
    );
    final child = await repository.createGoal(
      PlanGoalSaveData(
        parentGoalId: parent.id,
        title: '推进实验',
        goalLevel: PlanGoalLevel.quarter,
      ),
    );
    await container.read(planControllerProvider.future);
    final controller = container.read(planControllerProvider.notifier);
    await controller.openChildren(parent);

    await controller.updateCompletion(id: child.id, completed: true);

    final goal = container
        .read(planControllerProvider)
        .requireValue
        .goals
        .single;
    expect(goal.status, PlanGoalStatus.completed);
    expect(goal.completedAt, isNotNull);
  });

  test('archived goals are hidden by default and included on demand', () async {
    final repository = container.read(planRepositoryProvider);
    final active = await repository.createGoal(
      PlanGoalSaveData(title: '活动目标', goalLevel: PlanGoalLevel.month),
    );
    final archived = await repository.createGoal(
      PlanGoalSaveData(title: '归档目标', goalLevel: PlanGoalLevel.month),
    );
    await repository.archiveGoal(archived.id);

    var view = await container.read(planControllerProvider.future);
    expect(view.goals.map((goal) => goal.id), [active.id]);
    expect(view.filter.includeArchived, isFalse);

    await container
        .read(planControllerProvider.notifier)
        .toggleIncludeArchived(true);
    view = container.read(planControllerProvider).requireValue;
    expect(
      view.goals.map((goal) => goal.id),
      containsAll([active.id, archived.id]),
    );
    expect(
      view.goals.singleWhere((goal) => goal.id == archived.id).archivedAt,
      isNotNull,
    );
  });

  test('level and lifecycle filters apply without entering loading', () async {
    final repository = container.read(planRepositoryProvider);
    await repository.createGoal(
      PlanGoalSaveData(
        title: '过期月目标',
        goalLevel: PlanGoalLevel.month,
        startDate: '2026-06-01',
        targetDate: '2026-07-13',
      ),
    );
    await repository.createGoal(
      PlanGoalSaveData(
        title: '未来年度目标',
        goalLevel: PlanGoalLevel.year,
        startDate: '2026-08-01',
        targetDate: '2027-08-01',
      ),
    );
    await container.read(planControllerProvider.future);
    final controller = container.read(planControllerProvider.notifier);

    await controller.updateFilter(
      const PlanFilterState(level: PlanGoalLevel.month),
    );
    expect(
      container.read(planControllerProvider),
      isA<AsyncData<PlanViewState>>(),
    );
    expect(
      container.read(planControllerProvider).requireValue.goals.single.title,
      '过期月目标',
    );

    await controller.updateFilter(
      const PlanFilterState(lifecycle: PlanLifecycleFilter.notStarted),
    );
    expect(
      container.read(planControllerProvider).requireValue.goals.single.title,
      '未来年度目标',
    );
  });

  test('priority and target date sort modes are stable', () async {
    final repository = container.read(planRepositoryProvider);
    await repository.createGoal(
      PlanGoalSaveData(
        title: '较晚低优先级',
        goalLevel: PlanGoalLevel.month,
        targetDate: '2026-09-01',
        sortOrder: 5,
      ),
    );
    await repository.createGoal(
      PlanGoalSaveData(
        title: '较早高优先级',
        goalLevel: PlanGoalLevel.year,
        targetDate: '2026-08-01',
        sortOrder: 1,
      ),
    );
    await container.read(planControllerProvider.future);
    final controller = container.read(planControllerProvider.notifier);

    expect(
      container
          .read(planControllerProvider)
          .requireValue
          .goals
          .map((goal) => goal.sortOrder),
      [1, 5],
    );
    await controller.updateSortMode(PlanSortMode.targetDateAsc);
    expect(
      container
          .read(planControllerProvider)
          .requireValue
          .goals
          .map((goal) => goal.targetDate),
      ['2026-08-01', '2026-09-01'],
    );
  });

  test('archive restore and delete refresh the current view', () async {
    await container.read(planControllerProvider.future);
    final controller = container.read(planControllerProvider.notifier);
    await controller.createGoal(
      PlanGoalSaveData(title: '生命周期目标', goalLevel: PlanGoalLevel.month),
    );
    final id = container
        .read(planControllerProvider)
        .requireValue
        .goals
        .single
        .id;

    await controller.archiveGoal(id);
    expect(container.read(planControllerProvider).requireValue.goals, isEmpty);
    await controller.toggleIncludeArchived(true);
    expect(
      container
          .read(planControllerProvider)
          .requireValue
          .goals
          .single
          .archivedAt,
      isNotNull,
    );
    await controller.restoreGoal(id);
    expect(
      container
          .read(planControllerProvider)
          .requireValue
          .goals
          .single
          .archivedAt,
      isNull,
    );
    await controller.deleteGoal(id);
    expect(container.read(planControllerProvider).requireValue.goals, isEmpty);
  });

  test('child filters keep the current parent and breadcrumbs', () async {
    final repository = container.read(planRepositoryProvider);
    final parent = await repository.createGoal(
      PlanGoalSaveData(title: '父目标', goalLevel: PlanGoalLevel.year),
    );
    await repository.createGoal(
      PlanGoalSaveData(
        parentGoalId: parent.id,
        title: '月子目标',
        goalLevel: PlanGoalLevel.month,
      ),
    );
    await repository.createGoal(
      PlanGoalSaveData(
        parentGoalId: parent.id,
        title: '周子目标',
        goalLevel: PlanGoalLevel.week,
      ),
    );
    await container.read(planControllerProvider.future);
    final controller = container.read(planControllerProvider.notifier);
    await controller.openChildren(parent);
    await controller.updateFilter(
      const PlanFilterState(level: PlanGoalLevel.week),
    );

    final view = container.read(planControllerProvider).requireValue;
    expect(view.currentParentGoalId, parent.id);
    expect(view.breadcrumbs.single.id, parent.id);
    expect(view.goals.single.title, '周子目标');
  });

  test('deleteGoal refreshes the current list', () async {
    await container.read(planControllerProvider.future);
    final controller = container.read(planControllerProvider.notifier);
    await controller.createGoal(
      PlanGoalSaveData(title: '待删除目标', goalLevel: PlanGoalLevel.month),
    );
    final id = container
        .read(planControllerProvider)
        .requireValue
        .goals
        .single
        .id;

    await controller.deleteGoal(id);

    expect(container.read(planControllerProvider).requireValue.goals, isEmpty);
  });

  test('reload reads goals saved outside the controller', () async {
    expect(
      (await container.read(planControllerProvider.future)).goals,
      isEmpty,
    );
    await container
        .read(planRepositoryProvider)
        .createGoal(
          PlanGoalSaveData(title: '外部创建', goalLevel: PlanGoalLevel.life),
        );

    await container.read(planControllerProvider.notifier).reload();

    expect(
      container.read(planControllerProvider).requireValue.goals.single.title,
      '外部创建',
    );
  });

  test('initial repository failure exposes AsyncError', () async {
    final errorContainer = ProviderContainer(
      overrides: [
        planRepositoryProvider.overrideWithValue(
          _FailingPlanRepository(failInitialLoad: true),
        ),
      ],
    );
    addTearDown(errorContainer.dispose);

    await expectLater(
      errorContainer.read(planControllerProvider.future),
      throwsA(isA<StateError>()),
    );
    expect(
      errorContainer.read(planControllerProvider),
      isA<AsyncError<PlanViewState>>(),
    );
  });

  test('mutation failure is rethrown without clearing existing view', () async {
    final existing = _sampleGoal();
    final repository = _FailingPlanRepository(goals: [existing]);
    final errorContainer = ProviderContainer(
      overrides: [planRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(errorContainer.dispose);
    final initialView = await errorContainer.read(
      planControllerProvider.future,
    );

    await expectLater(
      errorContainer
          .read(planControllerProvider.notifier)
          .createGoal(
            PlanGoalSaveData(title: '失败目标', goalLevel: PlanGoalLevel.week),
          ),
      throwsA(isA<StateError>()),
    );

    expect(
      errorContainer.read(planControllerProvider),
      isA<AsyncData<PlanViewState>>(),
    );
    expect(
      errorContainer.read(planControllerProvider).requireValue,
      initialView,
    );
  });

  test('reload failure enters AsyncError', () async {
    final repository = _FailingPlanRepository(goals: [_sampleGoal()]);
    final errorContainer = ProviderContainer(
      overrides: [planRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(errorContainer.dispose);
    await errorContainer.read(planControllerProvider.future);
    repository.loadError = StateError('reload failed for test');

    await expectLater(
      errorContainer.read(planControllerProvider.notifier).reload(),
      throwsA(isA<StateError>()),
    );

    expect(
      errorContainer.read(planControllerProvider),
      isA<AsyncError<PlanViewState>>(),
    );
  });
}

final class _FailingPlanRepository implements PlanRepository {
  _FailingPlanRepository({this.failInitialLoad = false, this.goals = const []});

  final bool failInitialLoad;
  final List<PlanGoal> goals;
  Object? loadError;

  @override
  Future<List<PlanGoal>> listRootGoals({bool includeArchived = false}) async {
    if (failInitialLoad || loadError != null) {
      throw loadError ?? StateError('plan load failed for test');
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
  Future<PlanGoal> createGoal(PlanGoalSaveData data) {
    throw StateError('plan mutation failed for test');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PlanGoal _sampleGoal() {
  return const PlanGoal(
    id: 'existing-goal',
    userId: 'user-id',
    parentGoalId: null,
    title: '已有目标',
    description: null,
    goalLevel: PlanGoalLevel.year,
    status: PlanGoalStatus.inProgress,
    startDate: null,
    targetDate: null,
    completedAt: null,
    sortOrder: 0,
    createdAt: 1,
    updatedAt: 1,
  );
}
