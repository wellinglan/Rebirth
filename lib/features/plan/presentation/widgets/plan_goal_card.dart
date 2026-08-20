import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_goal_lifecycle.dart';

import 'plan_goal_actions_menu.dart';
import 'plan_goal_labels.dart';

class PlanGoalCard extends StatelessWidget {
  const PlanGoalCard({
    required this.goal,
    required this.today,
    required this.hierarchyDepth,
    required this.ancestorTitles,
    required this.onEdit,
    required this.onOpenChildren,
    required this.onAddChild,
    required this.onStatusChanged,
    required this.onAction,
    super.key,
  });

  final PlanGoal goal;
  final String today;
  final int hierarchyDepth;
  final List<String> ancestorTitles;
  final VoidCallback onEdit;
  final VoidCallback onOpenChildren;
  final VoidCallback onAddChild;
  final ValueChanged<PlanGoalStatus> onStatusChanged;
  final ValueChanged<PlanGoalAction> onAction;

  @override
  Widget build(BuildContext context) {
    final lifecycle = computePlanGoalLifecycle(goal: goal, today: today);
    final isArchived = lifecycle == PlanGoalLifecycle.archived;
    final path = ['Plan', ...ancestorTitles, goal.title].join(' / ');
    final hierarchyLabel = hierarchyDepth == 0
        ? '根目标'
        : '第 $hierarchyDepth 层子目标';

    return Semantics(
      container: true,
      label:
          '$hierarchyLabel，${goal.title}，${planGoalLifecycleLabel(lifecycle)}',
      child: Container(
        key: ValueKey('planGoalItem_${goal.id}'),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HierarchyMarker(goalId: goal.id, depth: hierarchyDepth),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        goal.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      _LifecycleBadge(lifecycle: lifecycle),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    path,
                    key: ValueKey('planGoalPath_${goal.id}'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _Metadata(
                        icon: Icons.layers_outlined,
                        text: planGoalLevelLabel(goal.goalLevel),
                      ),
                      _Metadata(
                        icon: Icons.calendar_today_outlined,
                        text:
                            '${goal.startDate ?? '未设置'} → ${goal.targetDate ?? '未设置'}',
                      ),
                      _Metadata(
                        icon: Icons.low_priority,
                        text: '优先级 ${goal.sortOrder}',
                      ),
                    ],
                  ),
                  if (goal.description != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      goal.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      TextButton.icon(
                        key: ValueKey('viewPlanGoalChildren_${goal.id}'),
                        onPressed: onOpenChildren,
                        icon: const Icon(Icons.account_tree_outlined),
                        label: const Text('子目标'),
                      ),
                      TextButton.icon(
                        key: ValueKey('addPlanGoalChild_${goal.id}'),
                        onPressed: isArchived ? null : onAddChild,
                        icon: const Icon(Icons.add),
                        label: const Text('添加子目标'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PlanGoalActionsMenu(
              goalId: goal.id,
              currentStatus: goal.status,
              isArchived: isArchived,
              onEdit: onEdit,
              onStatusSelected: onStatusChanged,
              onSelected: onAction,
            ),
          ],
        ),
      ),
    );
  }
}

class _HierarchyMarker extends StatelessWidget {
  const _HierarchyMarker({required this.goalId, required this.depth});

  final String goalId;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final indent = math.min(depth * 14.0, 56.0);
    final color = Theme.of(context).colorScheme.outlineVariant;
    return SizedBox(
      key: ValueKey(
        depth == 0
            ? 'planGoalHierarchyRoot_$goalId'
            : 'planGoalHierarchyChild_$goalId',
      ),
      width: 24 + indent,
      height: 34,
      child: Stack(
        children: [
          if (depth > 0) ...[
            Positioned(
              left: indent - 7,
              top: 0,
              bottom: 16,
              child: Container(width: 1, color: color),
            ),
            Positioned(
              left: indent - 7,
              top: 17,
              width: 9,
              child: Container(height: 1, color: color),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: Icon(
              depth == 0 ? Icons.flag_outlined : Icons.subdirectory_arrow_right,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
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
