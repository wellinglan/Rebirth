import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_goal_date_policy.dart';
import 'package:rebirth/features/plan/domain/plan_goal_save_data.dart';

import 'plan_controller.dart';
import 'plan_filter_state.dart';
import 'plan_view_state.dart';
import 'widgets/plan_filter_bar.dart';
import 'widgets/plan_goal_actions_menu.dart';
import 'widgets/plan_goal_card.dart';
import 'widgets/plan_goal_form_dialog.dart';

class PlanPage extends ConsumerWidget {
  const PlanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncView = ref.watch(planControllerProvider);
    final view = asyncView.asData?.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlanHeader(
          view: view,
          onCreate: () => _openGoalForm(
            context,
            ref,
            parentGoalId: view?.currentParentGoalId,
            defaultGoalLevel: _defaultChildLevel(view?.currentParent),
          ),
          onBack: () => _navigateBack(ref),
          onRoot: () => _navigateToBreadcrumb(ref, -1),
          onBreadcrumb: (index) => _navigateToBreadcrumb(ref, index),
        ),
        if (view != null)
          PlanFilterBar(
            filter: view.filter,
            onChanged: (filter) => _updateFilter(ref, filter),
          ),
        const Divider(height: 1),
        Expanded(
          child: asyncView.when(
            loading: () => const Center(
              key: ValueKey('planLoadingState'),
              child: CircularProgressIndicator(),
            ),
            error: (_, _) => Center(
              key: const ValueKey('planErrorState'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('计划暂时无法加载'),
                  const SizedBox(height: 12),
                  IconButton.filledTonal(
                    tooltip: '重新加载',
                    onPressed: () => _retry(ref),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            data: (data) => data.goals.isEmpty
                ? _PlanEmptyState(
                    isRoot: data.isRoot,
                    isFiltered: data.hasUnfilteredGoals,
                    onCreate: () => _openGoalForm(
                      context,
                      ref,
                      parentGoalId: data.currentParentGoalId,
                      defaultGoalLevel: _defaultChildLevel(data.currentParent),
                    ),
                  )
                : _PlanGoalList(
                    goals: data.goals,
                    today: data.today,
                    onEdit: (goal) => _openGoalForm(
                      context,
                      ref,
                      goal: goal,
                      parentGoalId: goal.parentGoalId,
                      defaultGoalLevel: goal.goalLevel,
                    ),
                    onOpenChildren: (goal) => _openChildren(ref, goal),
                    onAddChild: (goal) => _openGoalForm(
                      context,
                      ref,
                      parentGoalId: goal.id,
                      defaultGoalLevel: _childLevelFor(goal.goalLevel),
                    ),
                    onCompletionChanged: (goal, completed) =>
                        _updateCompletion(context, ref, goal.id, completed),
                    onAction: (goal, action) =>
                        _handleAction(context, ref, goal, action),
                  ),
          ),
        ),
      ],
    );
  }

  void _retry(WidgetRef ref) {
    ref.read(planControllerProvider.notifier).reload().ignore();
  }

  void _openChildren(WidgetRef ref, PlanGoal goal) {
    ref.read(planControllerProvider.notifier).openChildren(goal).ignore();
  }

  void _navigateBack(WidgetRef ref) {
    ref.read(planControllerProvider.notifier).navigateBack().ignore();
  }

  void _navigateToBreadcrumb(WidgetRef ref, int index) {
    ref
        .read(planControllerProvider.notifier)
        .navigateToBreadcrumb(index)
        .ignore();
  }

  void _updateFilter(WidgetRef ref, PlanFilterState filter) {
    ref.read(planControllerProvider.notifier).updateFilter(filter).ignore();
  }

  Future<void> _openGoalForm(
    BuildContext context,
    WidgetRef ref, {
    PlanGoal? goal,
    required String? parentGoalId,
    required PlanGoalLevel defaultGoalLevel,
  }) {
    const datePolicy = PlanGoalDatePolicy();
    final defaultStartDate = datePolicy.defaultStartDate(
      ref.read(dateTimeServiceProvider),
    );
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return PlanGoalFormDialog(
          existingGoal: goal,
          parentGoalId: parentGoalId,
          defaultStartDate: defaultStartDate,
          defaultGoalLevel: defaultGoalLevel,
          onSubmit: (data) => _saveGoal(ref, goal, data),
        );
      },
    );
  }

  Future<void> _saveGoal(WidgetRef ref, PlanGoal? goal, PlanGoalSaveData data) {
    final controller = ref.read(planControllerProvider.notifier);
    return goal == null
        ? controller.createGoal(data)
        : controller.updateGoal(id: goal.id, data: data);
  }

  Future<void> _updateCompletion(
    BuildContext context,
    WidgetRef ref,
    String goalId,
    bool completed,
  ) async {
    try {
      await ref
          .read(planControllerProvider.notifier)
          .updateCompletion(id: goalId, completed: completed);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('完成状态更新失败，请重试')));
      }
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    PlanGoal goal,
    PlanGoalAction action,
  ) async {
    if (action == PlanGoalAction.delete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const ValueKey('deletePlanGoalConfirmationDialog'),
          title: const Text('删除目标'),
          content: const Text('删除后该目标及其子目标将从普通列表中移除。是否继续？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const ValueKey('confirmDeletePlanGoalButton'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    try {
      final controller = ref.read(planControllerProvider.notifier);
      switch (action) {
        case PlanGoalAction.archive:
          await controller.archiveGoal(goal.id);
        case PlanGoalAction.restore:
          await controller.restoreGoal(goal.id);
        case PlanGoalAction.delete:
          await controller.deleteGoal(goal.id);
      }
    } catch (_) {
      if (!context.mounted) return;
      final message = switch (action) {
        PlanGoalAction.archive => '归档失败，请重试',
        PlanGoalAction.restore => '恢复失败，请重试',
        PlanGoalAction.delete => '删除失败，请重试',
      };
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  PlanGoalLevel _defaultChildLevel(PlanGoal? parent) {
    return parent == null
        ? PlanGoalLevel.month
        : _childLevelFor(parent.goalLevel);
  }

  PlanGoalLevel _childLevelFor(PlanGoalLevel parentLevel) {
    return switch (parentLevel) {
      PlanGoalLevel.life => PlanGoalLevel.year,
      PlanGoalLevel.year => PlanGoalLevel.quarter,
      PlanGoalLevel.quarter => PlanGoalLevel.month,
      PlanGoalLevel.month => PlanGoalLevel.week,
      PlanGoalLevel.week => PlanGoalLevel.day,
      PlanGoalLevel.day => PlanGoalLevel.day,
      PlanGoalLevel.custom => PlanGoalLevel.custom,
    };
  }
}

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({
    required this.view,
    required this.onCreate,
    required this.onBack,
    required this.onRoot,
    required this.onBreadcrumb,
  });

  final PlanViewState? view;
  final VoidCallback onCreate;
  final VoidCallback onBack;
  final VoidCallback onRoot;
  final ValueChanged<int> onBreadcrumb;

  @override
  Widget build(BuildContext context) {
    final currentParent = view?.currentParent;
    final isRoot = currentParent == null;
    final buttonLabel = isRoot ? '新建目标' : '新建子目标';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isRoot) ...[
            Row(
              children: [
                IconButton(
                  key: const ValueKey('planBackButton'),
                  tooltip: '返回上一级',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 4),
                TextButton(
                  key: const ValueKey('planRootBreadcrumbButton'),
                  onPressed: onRoot,
                  child: const Text('Plan'),
                ),
                for (
                  var index = 0;
                  index < (view?.breadcrumbs.length ?? 0);
                  index++
                ) ...[
                  const Icon(Icons.chevron_right, size: 18),
                  TextButton(
                    key: ValueKey('planBreadcrumb_$index'),
                    onPressed: () => onBreadcrumb(index),
                    child: Text(view!.breadcrumbs[index].title),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentParent?.title ?? 'Plan',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isRoot ? '让今天与长期方向相连' : '直接子目标',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              );
              final button = FilledButton.icon(
                key: const ValueKey('newPlanGoalButton'),
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: Text(buttonLabel),
              );

              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [title, const SizedBox(height: 12), button],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 16),
                  button,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PlanEmptyState extends StatelessWidget {
  const _PlanEmptyState({
    required this.isRoot,
    required this.isFiltered,
    required this.onCreate,
  });

  final bool isRoot;
  final bool isFiltered;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('planEmptyState'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isFiltered
                ? isRoot
                      ? '没有符合条件的目标。'
                      : '这个目标下没有符合条件的子目标。'
                : isRoot
                ? '还没有计划，先写下一个阶段目标。'
                : '这个目标还没有子目标。',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey('emptyNewPlanGoalButton'),
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: Text(isRoot ? '新建目标' : '新建子目标'),
          ),
        ],
      ),
    );
  }
}

class _PlanGoalList extends StatelessWidget {
  const _PlanGoalList({
    required this.goals,
    required this.today,
    required this.onEdit,
    required this.onOpenChildren,
    required this.onAddChild,
    required this.onCompletionChanged,
    required this.onAction,
  });

  final List<PlanGoal> goals;
  final String today;
  final ValueChanged<PlanGoal> onEdit;
  final ValueChanged<PlanGoal> onOpenChildren;
  final ValueChanged<PlanGoal> onAddChild;
  final Future<void> Function(PlanGoal goal, bool completed)
  onCompletionChanged;
  final Future<void> Function(PlanGoal goal, PlanGoalAction action) onAction;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const ValueKey('planGoalList'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      itemCount: goals.length + 1,
      separatorBuilder: (_, index) =>
          SizedBox(height: index == 0 ? AppLayout.cardGap : AppSpacing.xs),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Text(
            '共 ${goals.length} 个目标',
            style: Theme.of(context).textTheme.titleMedium,
          );
        }

        final goal = goals[index - 1];
        return PlanGoalCard(
          goal: goal,
          today: today,
          onEdit: () => onEdit(goal),
          onOpenChildren: () => onOpenChildren(goal),
          onAddChild: () => onAddChild(goal),
          onCompletionChanged: (completed) =>
              onCompletionChanged(goal, completed).ignore(),
          onAction: (action) => onAction(goal, action).ignore(),
        );
      },
    );
  }
}
