import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/plan/data/plan_repository_impl.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_goal_save_data.dart';
import 'package:rebirth/features/plan/domain/plan_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  const uuid = Uuid();
  late AppDatabase database;
  late DateTime currentTime;
  late int clockReads;
  late PlanRepositoryImpl repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    currentTime = DateTime(2026, 7, 14, 10);
    clockReads = 0;
    repository = PlanRepositoryImpl(
      database: database,
      dateTimeService: DateTimeService(
        now: () {
          clockReads += 1;
          return currentTime;
        },
      ),
    );
  });

  tearDown(() => database.close());

  test('createGoal writes normalized fields and creation metadata', () async {
    final goal = await repository.createGoal(
      PlanGoalSaveData(
        title: '  完成论文初稿  ',
        description: '  整理核心实验结果  ',
        goalLevel: PlanGoalLevel.quarter,
        status: PlanGoalStatus.inProgress,
        startDate: '2026-07-01',
        targetDate: '2026-09-30',
        sortOrder: 2,
      ),
    );
    final raw = await database.select(database.goals).getSingle();
    final settings = await database.select(database.appSettings).getSingle();
    final timestamp = currentTime.toUtc().millisecondsSinceEpoch;

    expect(clockReads, 1);
    expect(goal.title, '完成论文初稿');
    expect(goal.description, '整理核心实验结果');
    expect(goal.goalLevel, PlanGoalLevel.quarter);
    expect(goal.status, PlanGoalStatus.inProgress);
    expect(goal.createdAt, timestamp);
    expect(goal.updatedAt, timestamp);
    expect(raw.originDeviceId, settings.localInstallationId);
  });

  test('new schema creates and reads a custom goal', () async {
    final created = await repository.createGoal(
      PlanGoalSaveData(
        title: '自定义周期目标',
        goalLevel: PlanGoalLevel.custom,
        startDate: '2026-07-14',
        targetDate: '2026-08-20',
      ),
    );

    final loaded = await repository.getById(created.id);
    expect(loaded?.goalLevel, PlanGoalLevel.custom);
    expect(loaded?.targetDate, '2026-08-20');
  });

  test('empty title fails before any database write', () async {
    expect(
      () => PlanGoalSaveData(title: '   ', goalLevel: PlanGoalLevel.life),
      throwsA(isA<EmptyPlanGoalTitleException>()),
    );
    expect(await database.select(database.goals).get(), isEmpty);
    expect(clockReads, 0);
  });

  test('getById returns the active goal', () async {
    final created = await _create(repository, title: '读取目标');

    final loaded = await repository.getById(created.id);

    expect(loaded?.id, created.id);
    expect(loaded?.title, '读取目标');
  });

  test('root and child queries preserve the hierarchy', () async {
    final root = await _create(repository, title: '年度目标');
    final otherRoot = await _create(repository, title: '健康方向', sortOrder: 1);
    final child = await _create(
      repository,
      title: '季度里程碑',
      parentGoalId: root.id,
      level: PlanGoalLevel.quarter,
    );

    final roots = await repository.listRootGoals();
    final children = await repository.listChildren(root.id);

    expect(roots.map((goal) => goal.id), [root.id, otherRoot.id]);
    expect(children.map((goal) => goal.id), [child.id]);
  });

  test('listGoals filters by level, status, and parent', () async {
    final root = await _create(repository, title: '根目标');
    final matching = await _create(
      repository,
      title: '匹配目标',
      parentGoalId: root.id,
      level: PlanGoalLevel.month,
      status: PlanGoalStatus.paused,
    );
    await _create(
      repository,
      title: '不同状态',
      parentGoalId: root.id,
      level: PlanGoalLevel.month,
      status: PlanGoalStatus.inProgress,
    );
    await _create(
      repository,
      title: '不同层级',
      level: PlanGoalLevel.year,
      status: PlanGoalStatus.paused,
    );

    final goals = await repository.listGoals(
      level: PlanGoalLevel.month,
      status: PlanGoalStatus.paused,
      parentGoalId: root.id,
    );

    expect(goals.map((goal) => goal.id), [matching.id]);
  });

  test('updateGoal replaces all editable fields and updatedAt', () async {
    final root = await _create(repository, title: '新父目标');
    final created = await _create(repository, title: '旧标题');
    currentTime = currentTime.add(const Duration(minutes: 20));

    final updated = await repository.updateGoal(
      id: created.id,
      data: PlanGoalSaveData(
        parentGoalId: root.id,
        title: '  新标题  ',
        description: ' ',
        goalLevel: PlanGoalLevel.month,
        status: PlanGoalStatus.paused,
        startDate: '2026-07-14',
        targetDate: '2026-08-14',
        sortOrder: 4,
      ),
    );
    final timestamp = currentTime.toUtc().millisecondsSinceEpoch;

    expect(updated.parentGoalId, root.id);
    expect(updated.title, '新标题');
    expect(updated.description, isNull);
    expect(updated.goalLevel, PlanGoalLevel.month);
    expect(updated.status, PlanGoalStatus.paused);
    expect(updated.startDate, '2026-07-14');
    expect(updated.targetDate, '2026-08-14');
    expect(updated.sortOrder, 4);
    expect(updated.updatedAt, timestamp);
    expect(updated.updatedAt, greaterThan(created.updatedAt));
  });

  test('updateStatus sets and clears completedAt', () async {
    final created = await _create(repository, title: '状态目标');
    currentTime = currentTime.add(const Duration(hours: 1));
    final completionTimestamp = currentTime.toUtc().millisecondsSinceEpoch;

    final completed = await repository.updateStatus(
      id: created.id,
      status: PlanGoalStatus.completed,
    );

    expect(completed.status, PlanGoalStatus.completed);
    expect(completed.completedAt, completionTimestamp);
    expect(completed.updatedAt, completionTimestamp);

    currentTime = currentTime.add(const Duration(hours: 1));
    final resumedTimestamp = currentTime.toUtc().millisecondsSinceEpoch;
    final resumed = await repository.updateStatus(
      id: created.id,
      status: PlanGoalStatus.inProgress,
    );

    expect(resumed.status, PlanGoalStatus.inProgress);
    expect(resumed.completedAt, isNull);
    expect(resumed.updatedAt, resumedTimestamp);
  });

  test(
    'updateCompletion maps checkbox state to status and completedAt',
    () async {
      final created = await _create(repository, title: '完成状态目标');
      currentTime = currentTime.add(const Duration(minutes: 10));
      final completedAt = currentTime.toUtc().millisecondsSinceEpoch;

      final completed = await repository.updateCompletion(
        id: created.id,
        completed: true,
      );
      expect(completed.status, PlanGoalStatus.completed);
      expect(completed.completedAt, completedAt);
      expect(completed.updatedAt, completedAt);

      currentTime = currentTime.add(const Duration(minutes: 10));
      final resumed = await repository.updateCompletion(
        id: created.id,
        completed: false,
      );
      expect(resumed.status, PlanGoalStatus.inProgress);
      expect(resumed.completedAt, isNull);
      expect(resumed.updatedAt, currentTime.toUtc().millisecondsSinceEpoch);
    },
  );

  test('archive and restore affect the complete subtree', () async {
    final parent = await _create(repository, title: '归档父目标');
    final child = await _create(
      repository,
      title: '归档子目标',
      parentGoalId: parent.id,
    );
    currentTime = currentTime.add(const Duration(minutes: 30));
    final archivedAt = currentTime.toUtc().millisecondsSinceEpoch;

    await repository.archiveGoal(parent.id);

    expect(await repository.listRootGoals(), isEmpty);
    expect(await repository.listChildren(parent.id), isEmpty);
    final archivedRoots = await repository.listRootGoals(includeArchived: true);
    final archivedChildren = await repository.listChildren(
      parent.id,
      includeArchived: true,
    );
    expect(archivedRoots.single.archivedAt, archivedAt);
    expect(archivedChildren.single.id, child.id);
    expect(archivedChildren.single.archivedAt, archivedAt);

    currentTime = currentTime.add(const Duration(minutes: 30));
    await repository.restoreGoal(parent.id);
    expect((await repository.listRootGoals()).single.archivedAt, isNull);
    expect(
      (await repository.listChildren(parent.id)).single.archivedAt,
      isNull,
    );
  });

  test(
    'softDelete hides an archived subtree but preserves physical rows',
    () async {
      final created = await _create(repository, title: '待删除父目标');
      final child = await _create(
        repository,
        title: '待删除子目标',
        parentGoalId: created.id,
      );
      await repository.archiveGoal(created.id);
      currentTime = currentTime.add(const Duration(minutes: 30));
      final timestamp = currentTime.toUtc().millisecondsSinceEpoch;

      await repository.softDelete(created.id);

      expect(await repository.getById(created.id), isNull);
      expect(await repository.listGoals(), isEmpty);
      expect(await repository.listRootGoals(includeArchived: true), isEmpty);
      expect(
        await repository.listChildren(created.id, includeArchived: true),
        isEmpty,
      );
      final rows = await database.select(database.goals).get();
      expect(rows, hasLength(2));
      expect(rows.map((row) => row.id), containsAll([created.id, child.id]));
      expect(rows.every((row) => row.deletedAt == timestamp), isTrue);
      expect(rows.every((row) => row.updatedAt == timestamp), isTrue);
    },
  );

  test('queries and mutations are isolated to the active user', () async {
    final own = await _create(repository, title: '当前用户目标');
    final otherUserId = uuid.v4();
    await database
        .into(database.userProfiles)
        .insert(
          UserProfilesCompanion.insert(
            id: Value(otherUserId),
            timezoneId: 'Etc/UTC',
            isActive: const Value(false),
          ),
        );
    final otherGoalId = uuid.v4();
    await database
        .into(database.goals)
        .insert(
          GoalsCompanion.insert(
            id: Value(otherGoalId),
            userId: otherUserId,
            title: '其他用户目标',
            goalLevel: 'year',
          ),
        );

    expect((await repository.listGoals()).map((goal) => goal.id), [own.id]);
    expect(await repository.getById(otherGoalId), isNull);
    await expectLater(
      repository.updateStatus(
        id: otherGoalId,
        status: PlanGoalStatus.completed,
      ),
      throwsA(isA<PlanGoalNotFoundException>()),
    );
    await expectLater(
      repository.softDelete(otherGoalId),
      throwsA(isA<PlanGoalNotFoundException>()),
    );
    await expectLater(
      repository.archiveGoal(otherGoalId),
      throwsA(isA<PlanGoalNotFoundException>()),
    );
    await expectLater(
      repository.updateCompletion(id: otherGoalId, completed: true),
      throwsA(isA<PlanGoalNotFoundException>()),
    );
  });

  test('rejects a missing, cross-user, or self parent', () async {
    await expectLater(
      repository.createGoal(
        PlanGoalSaveData(
          parentGoalId: uuid.v4(),
          title: '无效父目标',
          goalLevel: PlanGoalLevel.month,
        ),
      ),
      throwsA(isA<PlanGoalNotFoundException>()),
    );

    final otherUserId = uuid.v4();
    await database
        .into(database.userProfiles)
        .insert(
          UserProfilesCompanion.insert(
            id: Value(otherUserId),
            timezoneId: 'Etc/UTC',
            isActive: const Value(false),
          ),
        );
    final otherGoalId = uuid.v4();
    await database
        .into(database.goals)
        .insert(
          GoalsCompanion.insert(
            id: Value(otherGoalId),
            userId: otherUserId,
            title: '其他用户父目标',
            goalLevel: 'year',
          ),
        );
    await expectLater(
      repository.createGoal(
        PlanGoalSaveData(
          parentGoalId: otherGoalId,
          title: '跨用户子目标',
          goalLevel: PlanGoalLevel.month,
        ),
      ),
      throwsA(isA<PlanGoalNotFoundException>()),
    );

    final goal = await _create(repository, title: '自身父目标');
    await expectLater(
      repository.updateGoal(
        id: goal.id,
        data: PlanGoalSaveData(
          parentGoalId: goal.id,
          title: goal.title,
          goalLevel: goal.goalLevel,
        ),
      ),
      throwsA(isA<InvalidPlanGoalParentException>()),
    );
  });

  test('unknown goal updates and deletes fail clearly', () async {
    final id = uuid.v4();
    await expectLater(
      repository.updateGoal(
        id: id,
        data: PlanGoalSaveData(title: '不存在', goalLevel: PlanGoalLevel.life),
      ),
      throwsA(isA<PlanGoalNotFoundException>()),
    );
    await expectLater(
      repository.updateStatus(id: id, status: PlanGoalStatus.paused),
      throwsA(isA<PlanGoalNotFoundException>()),
    );
    await expectLater(
      repository.updateCompletion(id: id, completed: true),
      throwsA(isA<PlanGoalNotFoundException>()),
    );
    await expectLater(
      repository.archiveGoal(id),
      throwsA(isA<PlanGoalNotFoundException>()),
    );
    await expectLater(
      repository.restoreGoal(id),
      throwsA(isA<PlanGoalNotFoundException>()),
    );
    await expectLater(
      repository.softDelete(id),
      throwsA(isA<PlanGoalNotFoundException>()),
    );
  });

  test('schema version is 3', () {
    expect(database.schemaVersion, 3);
  });
}

Future<PlanGoal> _create(
  PlanRepository repository, {
  required String title,
  String? parentGoalId,
  PlanGoalLevel level = PlanGoalLevel.year,
  PlanGoalStatus status = PlanGoalStatus.notStarted,
  int sortOrder = 0,
}) {
  return repository.createGoal(
    PlanGoalSaveData(
      parentGoalId: parentGoalId,
      title: title,
      goalLevel: level,
      status: status,
      sortOrder: sortOrder,
    ),
  );
}
