import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_goal_save_data.dart';
import 'package:rebirth/features/plan/domain/plan_repository.dart';

import 'plan_local_data_source.dart';

final class PlanRepositoryImpl implements PlanRepository {
  PlanRepositoryImpl({
    required db.AppDatabase database,
    required this.dateTimeService,
  }) : _database = database,
       _localDataSource = PlanLocalDataSource(database);

  final db.AppDatabase _database;
  final DateTimeService dateTimeService;
  final PlanLocalDataSource _localDataSource;

  @override
  Future<PlanGoal> createGoal(PlanGoalSaveData data) async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    await _validateParent(
      userId: bootstrap.activeUserId,
      parentGoalId: data.parentGoalId,
    );
    final snapshot = dateTimeService.currentSnapshot();
    final goal = await _localDataSource.insertGoal(
      userId: bootstrap.activeUserId,
      parentGoalId: data.parentGoalId,
      title: data.title,
      description: data.description,
      goalLevel: data.goalLevel.databaseValue,
      status: data.status.databaseValue,
      startDate: data.startDate,
      targetDate: data.targetDate,
      completedAt: data.status == PlanGoalStatus.completed
          ? snapshot.utcMilliseconds
          : null,
      sortOrder: data.sortOrder,
      timestamp: snapshot.utcMilliseconds,
      originDeviceId: bootstrap.localInstallationId,
    );
    return _toDomain(goal);
  }

  @override
  Future<PlanGoal?> getById(String id) async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final goal = await _localDataSource.selectById(
      userId: bootstrap.activeUserId,
      id: id,
    );
    return goal == null ? null : _toDomain(goal);
  }

  @override
  Future<List<PlanGoal>> listGoals({
    PlanGoalLevel? level,
    PlanGoalStatus? status,
    String? parentGoalId,
    bool includeArchived = false,
  }) async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    return _mapGoals(
      await _localDataSource.selectGoals(
        userId: bootstrap.activeUserId,
        goalLevel: level?.databaseValue,
        status: status?.databaseValue,
        parentGoalId: parentGoalId,
        includeArchived: includeArchived,
      ),
    );
  }

  @override
  Future<List<PlanGoal>> listRootGoals({bool includeArchived = false}) async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    return _mapGoals(
      await _localDataSource.selectRootGoals(
        userId: bootstrap.activeUserId,
        includeArchived: includeArchived,
      ),
    );
  }

  @override
  Future<List<PlanGoal>> listChildren(
    String parentGoalId, {
    bool includeArchived = false,
  }) async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    return _mapGoals(
      await _localDataSource.selectChildren(
        userId: bootstrap.activeUserId,
        parentGoalId: parentGoalId,
        includeArchived: includeArchived,
      ),
    );
  }

  @override
  Future<PlanGoal> updateGoal({
    required String id,
    required PlanGoalSaveData data,
  }) async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final existing = await _localDataSource.selectById(
      userId: bootstrap.activeUserId,
      id: id,
    );
    if (existing == null) {
      throw PlanGoalNotFoundException(id);
    }
    if (data.parentGoalId == id) {
      throw InvalidPlanGoalParentException(id);
    }
    await _validateParent(
      userId: bootstrap.activeUserId,
      parentGoalId: data.parentGoalId,
    );

    final snapshot = dateTimeService.currentSnapshot();
    final completedAt = switch (data.status) {
      PlanGoalStatus.completed =>
        existing.completedAt ?? snapshot.utcMilliseconds,
      _ => null,
    };
    final updated = await _localDataSource.updateById(
      userId: bootstrap.activeUserId,
      id: id,
      changes: db.GoalsCompanion(
        parentGoalId: Value(data.parentGoalId),
        title: Value(data.title),
        description: Value(data.description),
        goalLevel: Value(data.goalLevel.databaseValue),
        status: Value(data.status.databaseValue),
        startDate: Value(data.startDate),
        targetDate: Value(data.targetDate),
        completedAt: Value(completedAt),
        sortOrder: Value(data.sortOrder),
        updatedAt: Value(snapshot.utcMilliseconds),
      ),
    );
    if (updated == null) {
      throw PlanGoalNotFoundException(id);
    }
    return _toDomain(updated);
  }

  @override
  Future<PlanGoal> updateStatus({
    required String id,
    required PlanGoalStatus status,
  }) async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final snapshot = dateTimeService.currentSnapshot();
    final updated = await _localDataSource.updateById(
      userId: bootstrap.activeUserId,
      id: id,
      changes: db.GoalsCompanion(
        status: Value(status.databaseValue),
        completedAt: Value(
          status == PlanGoalStatus.completed ? snapshot.utcMilliseconds : null,
        ),
        updatedAt: Value(snapshot.utcMilliseconds),
      ),
    );
    if (updated == null) {
      throw PlanGoalNotFoundException(id);
    }
    return _toDomain(updated);
  }

  @override
  Future<PlanGoal> updateCompletion({
    required String id,
    required bool completed,
  }) async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final snapshot = dateTimeService.currentSnapshot();
    final updated = await _localDataSource.updateById(
      userId: bootstrap.activeUserId,
      id: id,
      changes: db.GoalsCompanion(
        status: Value(
          completed
              ? PlanGoalStatus.completed.databaseValue
              : PlanGoalStatus.inProgress.databaseValue,
        ),
        completedAt: Value(completed ? snapshot.utcMilliseconds : null),
        updatedAt: Value(snapshot.utcMilliseconds),
      ),
    );
    if (updated == null) {
      throw PlanGoalNotFoundException(id);
    }
    return _toDomain(updated);
  }

  @override
  Future<void> archiveGoal(String id) async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final timestamp = dateTimeService.currentSnapshot().utcMilliseconds;
    final archived = await _localDataSource.setArchivedForSubtree(
      userId: bootstrap.activeUserId,
      id: id,
      archivedAt: timestamp,
      timestamp: timestamp,
    );
    if (!archived) {
      throw PlanGoalNotFoundException(id);
    }
  }

  @override
  Future<void> restoreGoal(String id) async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final timestamp = dateTimeService.currentSnapshot().utcMilliseconds;
    final restored = await _localDataSource.setArchivedForSubtree(
      userId: bootstrap.activeUserId,
      id: id,
      archivedAt: null,
      timestamp: timestamp,
    );
    if (!restored) {
      throw PlanGoalNotFoundException(id);
    }
  }

  @override
  Future<void> softDelete(String id) async {
    final bootstrap = await _database.bootstrapDao.bootstrap();
    final snapshot = dateTimeService.currentSnapshot();
    final deleted = await _localDataSource.softDeleteSubtree(
      userId: bootstrap.activeUserId,
      id: id,
      timestamp: snapshot.utcMilliseconds,
    );
    if (!deleted) {
      throw PlanGoalNotFoundException(id);
    }
  }

  Future<void> _validateParent({
    required String userId,
    required String? parentGoalId,
  }) async {
    if (parentGoalId == null) {
      return;
    }
    final parent = await _localDataSource.selectById(
      userId: userId,
      id: parentGoalId,
    );
    if (parent == null) {
      throw PlanGoalNotFoundException(parentGoalId);
    }
  }

  PlanGoal _toDomain(db.Goal goal) {
    return PlanGoal(
      id: goal.id,
      userId: goal.userId,
      parentGoalId: goal.parentGoalId,
      title: goal.title,
      description: goal.description,
      goalLevel: planGoalLevelFromDatabase(goal.goalLevel),
      status: planGoalStatusFromDatabase(goal.status),
      startDate: goal.startDate,
      targetDate: goal.targetDate,
      completedAt: goal.completedAt,
      archivedAt: goal.archivedAt,
      sortOrder: goal.sortOrder,
      createdAt: goal.createdAt,
      updatedAt: goal.updatedAt,
    );
  }

  List<PlanGoal> _mapGoals(List<db.Goal> goals) {
    return goals.map(_toDomain).toList(growable: false);
  }
}
