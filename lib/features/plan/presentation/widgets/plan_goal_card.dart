import 'package:flutter/material.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';

import 'plan_goal_labels.dart';
import 'plan_goal_status_menu.dart';

class PlanGoalCard extends StatelessWidget {
  const PlanGoalCard({
    required this.goal,
    required this.onEdit,
    required this.onOpenChildren,
    required this.onAddChild,
    required this.onStatusChanged,
    super.key,
  });

  final PlanGoal goal;
  final VoidCallback onEdit;
  final VoidCallback onOpenChildren;
  final VoidCallback onAddChild;
  final Future<void> Function(PlanGoalStatus status) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('planGoalItem_${goal.id}'),
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            onTap: onEdit,
            title: Text(goal.title),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${planGoalLevelLabel(goal.goalLevel)} · '
                    '${planGoalStatusLabel(goal.status)}',
                  ),
                  Text('开始日期：${goal.startDate ?? '未设置'}'),
                  Text('目标日期：${goal.targetDate ?? '未设置'}'),
                  Text('优先级：${goal.sortOrder}'),
                  if (goal.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      goal.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            trailing: PlanGoalStatusMenu(
              goalId: goal.id,
              currentStatus: goal.status,
              onSelected: (status) => onStatusChanged(status).ignore(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  key: ValueKey('viewPlanGoalChildren_${goal.id}'),
                  onPressed: onOpenChildren,
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('子目标'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  key: ValueKey('addPlanGoalChild_${goal.id}'),
                  onPressed: onAddChild,
                  icon: const Icon(Icons.add),
                  label: const Text('添加子目标'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
