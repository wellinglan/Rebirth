import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_goal_save_data.dart';

import 'plan_controller.dart';
import 'widgets/plan_goal_card.dart';
import 'widgets/plan_goal_form_dialog.dart';

class PlanPage extends ConsumerWidget {
  const PlanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(planControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlanHeader(onCreate: () => _openGoalForm(context, ref)),
        const Divider(height: 1),
        Expanded(
          child: goals.when(
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
            data: (items) => items.isEmpty
                ? _PlanEmptyState(onCreate: () => _openGoalForm(context, ref))
                : _PlanGoalList(
                    goals: items,
                    onEdit: (goal) => _openGoalForm(context, ref, goal: goal),
                    onStatusChanged: (goal, status) =>
                        _updateStatus(context, ref, goal.id, status),
                  ),
          ),
        ),
      ],
    );
  }

  void _retry(WidgetRef ref) {
    ref.read(planControllerProvider.notifier).reload().ignore();
  }

  Future<void> _openGoalForm(
    BuildContext context,
    WidgetRef ref, {
    PlanGoal? goal,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return PlanGoalFormDialog(
          existingGoal: goal,
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

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    String goalId,
    PlanGoalStatus status,
  ) async {
    try {
      await ref
          .read(planControllerProvider.notifier)
          .updateStatus(id: goalId, status: status);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('状态更新失败，请重试')));
      }
    }
  }
}

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Plan', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('让今天与长期方向相连', style: Theme.of(context).textTheme.bodyMedium),
            ],
          );
          final button = FilledButton.icon(
            key: const ValueKey('newPlanGoalButton'),
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('新建目标'),
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
    );
  }
}

class _PlanEmptyState extends StatelessWidget {
  const _PlanEmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('planEmptyState'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('还没有计划，先写下一个阶段目标。'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey('emptyNewPlanGoalButton'),
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('新建目标'),
          ),
        ],
      ),
    );
  }
}

class _PlanGoalList extends StatelessWidget {
  const _PlanGoalList({
    required this.goals,
    required this.onEdit,
    required this.onStatusChanged,
  });

  final List<PlanGoal> goals;
  final ValueChanged<PlanGoal> onEdit;
  final Future<void> Function(PlanGoal goal, PlanGoalStatus status)
  onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const ValueKey('planGoalList'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: goals.length + 1,
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 12 : 8),
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
          onEdit: () => onEdit(goal),
          onStatusChanged: (status) => onStatusChanged(goal, status),
        );
      },
    );
  }
}
