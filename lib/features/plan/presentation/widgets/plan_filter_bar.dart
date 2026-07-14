import 'package:flutter/material.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/presentation/plan_filter_state.dart';

import 'plan_goal_labels.dart';

class PlanFilterBar extends StatelessWidget {
  const PlanFilterBar({
    required this.filter,
    required this.onChanged,
    super.key,
  });

  final PlanFilterState filter;
  final ValueChanged<PlanFilterState> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              key: const ValueKey('planLevelFilter'),
              initialValue: filter.level?.name ?? 'all',
              isDense: true,
              decoration: const InputDecoration(
                labelText: '层级',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('全部')),
                ...PlanGoalLevel.values.map(
                  (level) => DropdownMenuItem(
                    value: level.name,
                    child: Text(planGoalLevelLabel(level)),
                  ),
                ),
              ],
              onChanged: (value) {
                final level = value == null || value == 'all'
                    ? null
                    : PlanGoalLevel.values.byName(value);
                onChanged(filter.copyWith(level: level));
              },
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<PlanLifecycleFilter>(
              key: const ValueKey('planLifecycleFilter'),
              initialValue: filter.lifecycle,
              isDense: true,
              decoration: const InputDecoration(
                labelText: '生命周期',
                border: OutlineInputBorder(),
              ),
              items: PlanLifecycleFilter.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_lifecycleFilterLabel(value)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) return;
                onChanged(
                  filter.copyWith(
                    lifecycle: value,
                    includeArchived: value == PlanLifecycleFilter.archived
                        ? true
                        : filter.includeArchived,
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<PlanSortMode>(
              key: const ValueKey('planSortMode'),
              initialValue: filter.sortMode,
              isDense: true,
              decoration: const InputDecoration(
                labelText: '排序',
                border: OutlineInputBorder(),
              ),
              items: PlanSortMode.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_sortModeLabel(value)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  onChanged(filter.copyWith(sortMode: value));
                }
              },
            ),
          ),
          FilterChip(
            key: const ValueKey('planIncludeArchivedFilter'),
            selected: filter.includeArchived,
            avatar: const Icon(Icons.archive_outlined, size: 18),
            label: const Text('显示归档'),
            onSelected: (value) =>
                onChanged(filter.copyWith(includeArchived: value)),
          ),
        ],
      ),
    );
  }
}

String _lifecycleFilterLabel(PlanLifecycleFilter value) => switch (value) {
  PlanLifecycleFilter.all => '全部',
  PlanLifecycleFilter.notStarted => '未开始',
  PlanLifecycleFilter.inProgress => '进行中',
  PlanLifecycleFilter.overdue => '已过期',
  PlanLifecycleFilter.completed => '已完成',
  PlanLifecycleFilter.archived => '已归档',
};

String _sortModeLabel(PlanSortMode value) => switch (value) {
  PlanSortMode.priorityAsc => '优先级',
  PlanSortMode.targetDateAsc => '目标日期',
  PlanSortMode.createdAtDesc => '创建时间',
  PlanSortMode.levelThenPriority => '层级',
};
