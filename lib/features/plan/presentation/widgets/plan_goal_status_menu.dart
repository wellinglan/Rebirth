import 'package:flutter/material.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';

import 'plan_goal_labels.dart';

class PlanGoalStatusMenu extends StatelessWidget {
  const PlanGoalStatusMenu({
    required this.goalId,
    required this.currentStatus,
    required this.onSelected,
    super.key,
  });

  final String goalId;
  final PlanGoalStatus currentStatus;
  final ValueChanged<PlanGoalStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<PlanGoalStatus>(
      key: ValueKey('planGoalStatusMenu_$goalId'),
      tooltip: '切换状态',
      icon: const Icon(Icons.more_vert),
      onSelected: onSelected,
      itemBuilder: (context) {
        return PlanGoalStatus.values
            .map((status) {
              return CheckedPopupMenuItem<PlanGoalStatus>(
                value: status,
                checked: status == currentStatus,
                child: Text(planGoalStatusLabel(status)),
              );
            })
            .toList(growable: false);
      },
    );
  }
}
