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

  test('initially loads an empty root goal list', () async {
    expect(
      container.read(planControllerProvider),
      isA<AsyncLoading<List<PlanGoal>>>(),
    );

    expect(await container.read(planControllerProvider.future), isEmpty);
  });

  test('createGoal refreshes the root list', () async {
    await container.read(planControllerProvider.future);

    await container
        .read(planControllerProvider.notifier)
        .createGoal(
          PlanGoalSaveData(title: '年度研究方向', goalLevel: PlanGoalLevel.year),
        );

    final goals = container.read(planControllerProvider).requireValue;
    expect(goals, hasLength(1));
    expect(goals.single.title, '年度研究方向');
  });

  test('updateStatus refreshes the current list', () async {
    await container.read(planControllerProvider.future);
    final controller = container.read(planControllerProvider.notifier);
    await controller.createGoal(
      PlanGoalSaveData(title: '推进实验', goalLevel: PlanGoalLevel.quarter),
    );
    final id = container.read(planControllerProvider).requireValue.single.id;

    await controller.updateStatus(id: id, status: PlanGoalStatus.completed);

    final goal = container.read(planControllerProvider).requireValue.single;
    expect(goal.status, PlanGoalStatus.completed);
    expect(goal.completedAt, isNotNull);
  });

  test('updateGoal refreshes the current list', () async {
    await container.read(planControllerProvider.future);
    final controller = container.read(planControllerProvider.notifier);
    await controller.createGoal(
      PlanGoalSaveData(title: '旧标题', goalLevel: PlanGoalLevel.month),
    );
    final id = container.read(planControllerProvider).requireValue.single.id;

    await controller.updateGoal(
      id: id,
      data: PlanGoalSaveData(
        title: '新标题',
        description: '阶段说明',
        goalLevel: PlanGoalLevel.quarter,
      ),
    );

    final goal = container.read(planControllerProvider).requireValue.single;
    expect(goal.title, '新标题');
    expect(goal.description, '阶段说明');
    expect(goal.goalLevel, PlanGoalLevel.quarter);
  });

  test('deleteGoal refreshes the current list', () async {
    await container.read(planControllerProvider.future);
    final controller = container.read(planControllerProvider.notifier);
    await controller.createGoal(
      PlanGoalSaveData(title: '待删除目标', goalLevel: PlanGoalLevel.month),
    );
    final id = container.read(planControllerProvider).requireValue.single.id;

    await controller.deleteGoal(id);

    expect(container.read(planControllerProvider).requireValue, isEmpty);
  });

  test('loadChildren switches to and refreshes the child list', () async {
    await container.read(planControllerProvider.future);
    final controller = container.read(planControllerProvider.notifier);
    await controller.createGoal(
      PlanGoalSaveData(title: '父目标', goalLevel: PlanGoalLevel.year),
    );
    final parent = container.read(planControllerProvider).requireValue.single;
    await controller.createGoal(
      PlanGoalSaveData(
        parentGoalId: parent.id,
        title: '子目标',
        goalLevel: PlanGoalLevel.quarter,
      ),
    );

    await controller.loadChildren(parent.id);

    final children = container.read(planControllerProvider).requireValue;
    expect(children, hasLength(1));
    expect(children.single.parentGoalId, parent.id);
    expect(children.single.title, '子目标');
  });

  test('reload reads goals saved outside the controller', () async {
    expect(await container.read(planControllerProvider.future), isEmpty);
    await container
        .read(planRepositoryProvider)
        .createGoal(
          PlanGoalSaveData(title: '外部创建', goalLevel: PlanGoalLevel.life),
        );

    await container.read(planControllerProvider.notifier).reload();

    expect(
      container.read(planControllerProvider).requireValue.single.title,
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
      isA<AsyncError<List<PlanGoal>>>(),
    );
  });

  test('mutation failure is rethrown without clearing existing data', () async {
    final existing = _sampleGoal();
    final repository = _FailingPlanRepository(goals: [existing]);
    final errorContainer = ProviderContainer(
      overrides: [planRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(errorContainer.dispose);
    expect(await errorContainer.read(planControllerProvider.future), [
      existing,
    ]);

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
      isA<AsyncData<List<PlanGoal>>>(),
    );
    expect(errorContainer.read(planControllerProvider).requireValue, [
      existing,
    ]);
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
      isA<AsyncError<List<PlanGoal>>>(),
    );
  });
}

final class _FailingPlanRepository implements PlanRepository {
  _FailingPlanRepository({this.failInitialLoad = false, this.goals = const []});

  final bool failInitialLoad;
  final List<PlanGoal> goals;
  Object? loadError;

  @override
  Future<List<PlanGoal>> listRootGoals() async {
    if (failInitialLoad || loadError != null) {
      throw loadError ?? StateError('plan load failed for test');
    }
    return goals;
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
