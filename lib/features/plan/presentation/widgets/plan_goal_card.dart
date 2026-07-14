import 'package:flutter/material.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';

import 'plan_goal_labels.dart';
import 'plan_goal_status_menu.dart';

class PlanGoalCard extends StatelessWidget {
  const PlanGoalCard({
    required this.goal,
    required this.onEdit,
    required this.onStatusChanged,
    super.key,
  });

  final PlanGoal goal;
  final VoidCallback onEdit;
  final Future<void> Function(PlanGoalStatus status) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('planGoalItem_${goal.id}'),
      margin: EdgeInsets.zero,
      child: ListTile(
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
              if (goal.targetDate != null) Text('目标日期：${goal.targetDate}'),
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
    );
  }
}
