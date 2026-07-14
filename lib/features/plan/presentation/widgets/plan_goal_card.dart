import 'package:flutter/material.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_goal_lifecycle.dart';

import 'plan_goal_actions_menu.dart';
import 'plan_goal_labels.dart';

class PlanGoalCard extends StatelessWidget {
  const PlanGoalCard({
    required this.goal,
    required this.today,
    required this.onEdit,
    required this.onOpenChildren,
    required this.onAddChild,
    required this.onCompletionChanged,
    required this.onAction,
    super.key,
  });

  final PlanGoal goal;
  final String today;
  final VoidCallback onEdit;
  final VoidCallback onOpenChildren;
  final VoidCallback onAddChild;
  final ValueChanged<bool> onCompletionChanged;
  final ValueChanged<PlanGoalAction> onAction;

  @override
  Widget build(BuildContext context) {
    final lifecycle = computePlanGoalLifecycle(goal: goal, today: today);
    final isArchived = lifecycle == PlanGoalLifecycle.archived;
    final isCompleted = goal.status == PlanGoalStatus.completed;

    return Card(
      key: ValueKey('planGoalItem_${goal.id}'),
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            onTap: onEdit,
            leading: Checkbox(
              key: ValueKey('planGoalCompleted_${goal.id}'),
              value: isCompleted,
              onChanged: isArchived
                  ? null
                  : (value) => onCompletionChanged(value ?? false),
            ),
            title: Row(
              children: [
                Expanded(child: Text(goal.title)),
                const SizedBox(width: 8),
                _LifecycleBadge(lifecycle: lifecycle),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(planGoalLevelLabel(goal.goalLevel)),
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
            trailing: PlanGoalActionsMenu(
              goalId: goal.id,
              isArchived: isArchived,
              onSelected: onAction,
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
                  onPressed: isArchived ? null : onAddChild,
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

class _LifecycleBadge extends StatelessWidget {
  const _LifecycleBadge({required this.lifecycle});

  final PlanGoalLifecycle lifecycle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (lifecycle) {
      PlanGoalLifecycle.notStarted => colors.secondary,
      PlanGoalLifecycle.inProgress => colors.primary,
      PlanGoalLifecycle.overdue => colors.error,
      PlanGoalLifecycle.completed => colors.tertiary,
      PlanGoalLifecycle.archived => colors.outline,
    };
    return Container(
      key: const ValueKey('planGoalLifecycleBadge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        planGoalLifecycleLabel(lifecycle),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
