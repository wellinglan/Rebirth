import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';

import 'plan_controller.dart';

class PlanPage extends ConsumerWidget {
  const PlanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(planControllerProvider);

    return goals.when(
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
          ? const Center(
              key: ValueKey('planEmptyState'),
              child: Text('还没有计划，先写下一个阶段目标。'),
            )
          : _PlanGoalList(goals: items),
    );
  }

  void _retry(WidgetRef ref) {
    ref.read(planControllerProvider.notifier).reload().ignore();
  }
}

class _PlanGoalList extends StatelessWidget {
  const _PlanGoalList({required this.goals});

  final List<PlanGoal> goals;

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
        return Card(
          key: ValueKey('planGoalItem_${goal.id}'),
          margin: EdgeInsets.zero,
          child: ListTile(
            title: Text(goal.title),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_levelLabel(goal.goalLevel)} · '
                    '${_statusLabel(goal.status)}',
                  ),
                  if (goal.targetDate != null) Text('目标日期：${goal.targetDate}'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String _levelLabel(PlanGoalLevel level) {
  return switch (level) {
    PlanGoalLevel.life => '人生',
    PlanGoalLevel.year => '年度',
    PlanGoalLevel.quarter => '季度',
    PlanGoalLevel.month => '月度',
    PlanGoalLevel.week => '每周',
    PlanGoalLevel.day => '每日',
  };
}

String _statusLabel(PlanGoalStatus status) {
  return switch (status) {
    PlanGoalStatus.notStarted => '未开始',
    PlanGoalStatus.inProgress => '进行中',
    PlanGoalStatus.completed => '已完成',
    PlanGoalStatus.paused => '暂停',
    PlanGoalStatus.cancelled => '已取消',
  };
}
