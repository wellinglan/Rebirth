import 'package:rebirth/features/plan/domain/plan_goal.dart';

String planGoalLevelLabel(PlanGoalLevel level) {
  return switch (level) {
    PlanGoalLevel.life => '人生',
    PlanGoalLevel.year => '年度',
    PlanGoalLevel.quarter => '季度',
    PlanGoalLevel.month => '月度',
    PlanGoalLevel.week => '每周',
    PlanGoalLevel.day => '每日',
  };
}

String planGoalStatusLabel(PlanGoalStatus status) {
  return switch (status) {
    PlanGoalStatus.notStarted => '未开始',
    PlanGoalStatus.inProgress => '进行中',
    PlanGoalStatus.completed => '已完成',
    PlanGoalStatus.paused => '暂停',
    PlanGoalStatus.cancelled => '已取消',
  };
}
