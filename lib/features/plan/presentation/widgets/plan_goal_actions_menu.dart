import 'package:flutter/material.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';

import 'plan_goal_labels.dart';

enum PlanGoalAction { archive, restore, delete }

class PlanGoalActionsMenu extends StatelessWidget {
  const PlanGoalActionsMenu({
    required this.goalId,
    required this.currentStatus,
    required this.isArchived,
    required this.onEdit,
    required this.onStatusSelected,
    required this.onSelected,
    super.key,
  });

  final String goalId;
  final PlanGoalStatus currentStatus;
  final bool isArchived;
  final VoidCallback onEdit;
  final ValueChanged<PlanGoalStatus> onStatusSelected;
  final ValueChanged<PlanGoalAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          key: ValueKey('editPlanGoal_$goalId'),
          leadingIcon: const Icon(Icons.edit_outlined),
          onPressed: onEdit,
          child: const Text('编辑目标'),
        ),
        const Divider(),
        for (final status in PlanGoalStatus.values)
          MenuItemButton(
            key: ValueKey('setPlanGoalStatus_${goalId}_${status.name}'),
            leadingIcon: Icon(
              status == currentStatus
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            onPressed: isArchived ? null : () => onStatusSelected(status),
            child: Text('设为${planGoalStatusLabel(status)}'),
          ),
        const Divider(),
        MenuItemButton(
          key: ValueKey('archivePlanGoal_$goalId'),
          leadingIcon: Icon(
            isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
          ),
          onPressed: () => onSelected(
            isArchived ? PlanGoalAction.restore : PlanGoalAction.archive,
          ),
          child: Text(isArchived ? '恢复归档' : '归档'),
        ),
        MenuItemButton(
          key: ValueKey('deletePlanGoal_$goalId'),
          leadingIcon: const Icon(Icons.delete_outline),
          onPressed: () => onSelected(PlanGoalAction.delete),
          child: const Text('删除'),
        ),
      ],
      builder: (context, controller, child) => IconButton(
        key: ValueKey('planGoalActionsMenu_$goalId'),
        tooltip: '目标操作',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.more_vert),
      ),
    );
  }
}
