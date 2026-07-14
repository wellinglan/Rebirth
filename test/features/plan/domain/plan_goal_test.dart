import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_goal_save_data.dart';

void main() {
  test('normalizes title and blank description', () {
    final data = PlanGoalSaveData(
      title: '  完成阶段论文  ',
      description: '  ',
      goalLevel: PlanGoalLevel.quarter,
    );

    expect(data.title, '完成阶段论文');
    expect(data.description, isNull);
  });

  test('rejects an empty title', () {
    expect(
      () => PlanGoalSaveData(title: ' \n\t ', goalLevel: PlanGoalLevel.year),
      throwsA(isA<EmptyPlanGoalTitleException>()),
    );
  });

  test('validates date format and real calendar dates', () {
    for (final date in ['2026/07/14', '2026-7-14', '2026-02-30']) {
      expect(
        () => PlanGoalSaveData(
          title: '日期测试',
          goalLevel: PlanGoalLevel.month,
          startDate: date,
        ),
        throwsA(isA<InvalidPlanGoalDateException>()),
      );
    }
  });

  test('target date cannot be before start date', () {
    expect(
      () => PlanGoalSaveData(
        title: '日期范围测试',
        goalLevel: PlanGoalLevel.month,
        startDate: '2026-07-14',
        targetDate: '2026-07-13',
      ),
      throwsA(isA<InvalidPlanGoalDateRangeException>()),
    );
  });

  test('accepts equal start and target dates', () {
    final data = PlanGoalSaveData(
      title: '当天目标',
      goalLevel: PlanGoalLevel.day,
      startDate: '2026-07-14',
      targetDate: '2026-07-14',
    );

    expect(data.startDate, data.targetDate);
  });

  test('rejects a negative sort order', () {
    expect(
      () => PlanGoalSaveData(
        title: '排序测试',
        goalLevel: PlanGoalLevel.week,
        sortOrder: -1,
      ),
      throwsArgumentError,
    );
  });

  test('goal level enum maps to and from database strings', () {
    for (final level in PlanGoalLevel.values) {
      expect(planGoalLevelFromDatabase(level.databaseValue), level);
    }
  });

  test('goal status enum maps to and from database strings', () {
    const expected = <PlanGoalStatus, String>{
      PlanGoalStatus.notStarted: 'not_started',
      PlanGoalStatus.inProgress: 'in_progress',
      PlanGoalStatus.completed: 'completed',
      PlanGoalStatus.paused: 'paused',
      PlanGoalStatus.cancelled: 'cancelled',
    };

    for (final entry in expected.entries) {
      expect(entry.key.databaseValue, entry.value);
      expect(planGoalStatusFromDatabase(entry.value), entry.key);
    }
  });
}
