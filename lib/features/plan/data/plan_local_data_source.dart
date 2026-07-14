import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart' as db;
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

final class PlanLocalDataSource {
  const PlanLocalDataSource(this.database);

  final db.AppDatabase database;

  Future<db.Goal> insertGoal({
    required String userId,
    required String? parentGoalId,
    required String title,
    required String? description,
    required String goalLevel,
    required String status,
    required String? startDate,
    required String? targetDate,
    required int? completedAt,
    required int sortOrder,
    required int timestamp,
    required String originDeviceId,
  }) async {
    final id = _uuid.v4();
    await database
        .into(database.goals)
        .insert(
          db.GoalsCompanion.insert(
            id: Value(id),
            userId: userId,
            parentGoalId: Value(parentGoalId),
            title: title,
            description: Value(description),
            goalLevel: goalLevel,
            status: Value(status),
            startDate: Value(startDate),
            targetDate: Value(targetDate),
            completedAt: Value(completedAt),
            sortOrder: Value(sortOrder),
            createdAt: Value(timestamp),
            updatedAt: Value(timestamp),
            originDeviceId: Value(originDeviceId),
          ),
        );
    return (await selectById(userId: userId, id: id))!;
  }

  Future<db.Goal?> selectById({required String userId, required String id}) {
    return (database.select(database.goals)..where(
          (row) =>
              row.userId.equals(userId) &
              row.id.equals(id) &
              row.deletedAt.isNull(),
        ))
        .getSingleOrNull();
  }

  Future<List<db.Goal>> selectGoals({
    required String userId,
    String? goalLevel,
    String? status,
    String? parentGoalId,
  }) {
    final query = database.select(database.goals)
      ..where((row) => row.userId.equals(userId) & row.deletedAt.isNull());
    if (goalLevel != null) {
      query.where((row) => row.goalLevel.equals(goalLevel));
    }
    if (status != null) {
      query.where((row) => row.status.equals(status));
    }
    if (parentGoalId != null) {
      query.where((row) => row.parentGoalId.equals(parentGoalId));
    }
    _order(query);
    return query.get();
  }

  Future<List<db.Goal>> selectRootGoals({required String userId}) {
    final query = database.select(database.goals)
      ..where(
        (row) =>
            row.userId.equals(userId) &
            row.deletedAt.isNull() &
            row.parentGoalId.isNull(),
      );
    _order(query);
    return query.get();
  }

  Future<List<db.Goal>> selectChildren({
    required String userId,
    required String parentGoalId,
  }) {
    final query = database.select(database.goals)
      ..where(
        (row) =>
            row.userId.equals(userId) &
            row.deletedAt.isNull() &
            row.parentGoalId.equals(parentGoalId),
      );
    _order(query);
    return query.get();
  }

  Future<db.Goal?> updateById({
    required String userId,
    required String id,
    required db.GoalsCompanion changes,
  }) async {
    final affectedRows =
        await (database.update(database.goals)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.id.equals(id) &
                  row.deletedAt.isNull(),
            ))
            .write(changes);
    if (affectedRows == 0) {
      return null;
    }
    return selectById(userId: userId, id: id);
  }

  Future<bool> softDeleteById({
    required String userId,
    required String id,
    required int timestamp,
  }) async {
    final affectedRows =
        await (database.update(database.goals)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.id.equals(id) &
                  row.deletedAt.isNull(),
            ))
            .write(
              db.GoalsCompanion(
                deletedAt: Value(timestamp),
                updatedAt: Value(timestamp),
              ),
            );
    return affectedRows > 0;
  }

  void _order(SimpleSelectStatement<db.$GoalsTable, db.Goal> query) {
    query.orderBy([
      (row) => OrderingTerm.asc(row.sortOrder),
      (row) => OrderingTerm.asc(row.targetDate.isNull()),
      (row) => OrderingTerm.asc(row.targetDate),
      (row) => OrderingTerm.desc(row.createdAt),
    ]);
  }
}
