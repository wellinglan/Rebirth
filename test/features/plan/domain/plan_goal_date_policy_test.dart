import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_goal_date_policy.dart';

void main() {
  const policy = PlanGoalDatePolicy();

  test('default start date comes from DateTimeService', () {
    final service = DateTimeService(now: () => DateTime(2026, 7, 14, 9));
    expect(policy.defaultStartDate(service), '2026-07-14');
  });

  test('day and week targets use calendar days', () {
    expect(
      policy.targetDate(level: PlanGoalLevel.day, startDate: '2026-07-14'),
      '2026-07-15',
    );
    expect(
      policy.targetDate(level: PlanGoalLevel.week, startDate: '2026-07-14'),
      '2026-07-21',
    );
  });

  test('month target clamps to the last valid day', () {
    expect(
      policy.targetDate(level: PlanGoalLevel.month, startDate: '2026-07-14'),
      '2026-08-14',
    );
    expect(
      policy.targetDate(level: PlanGoalLevel.month, startDate: '2026-03-31'),
      '2026-04-30',
    );
    expect(
      policy.targetDate(level: PlanGoalLevel.month, startDate: '2026-01-31'),
      '2026-02-28',
    );
    expect(
      policy.targetDate(level: PlanGoalLevel.month, startDate: '2028-01-31'),
      '2028-02-29',
    );
  });

  test('quarter target adds three natural months with clamping', () {
    expect(
      policy.targetDate(level: PlanGoalLevel.quarter, startDate: '2026-11-30'),
      '2027-02-28',
    );
  });

  test('year target handles leap day', () {
    expect(
      policy.targetDate(level: PlanGoalLevel.year, startDate: '2028-02-29'),
      '2029-02-28',
    );
  });

  test('life target is null and custom preserves the supplied target', () {
    expect(
      policy.targetDate(level: PlanGoalLevel.life, startDate: '2026-07-14'),
      isNull,
    );
    expect(
      policy.targetDate(
        level: PlanGoalLevel.custom,
        startDate: '2026-07-14',
        currentTargetDate: '2026-09-01',
      ),
      '2026-09-01',
    );
  });

  test('rejects an invalid start date', () {
    expect(
      () => policy.targetDate(
        level: PlanGoalLevel.month,
        startDate: '2026-02-30',
      ),
      throwsArgumentError,
    );
  });
}
