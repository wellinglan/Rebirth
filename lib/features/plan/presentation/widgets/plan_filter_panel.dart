import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/presentation/plan_filter_state.dart';

import 'plan_goal_labels.dart';

class PlanFilterPanel extends StatelessWidget {
  const PlanFilterPanel({
    required this.filter,
    required this.onChanged,
    required this.onClose,
    super.key,
  });

  final PlanFilterState filter;
  final ValueChanged<PlanFilterState> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      key: const ValueKey('planFilterPanel'),
      elevation: 6,
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        key: const ValueKey('planFilterPanelScroll'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_alt_outlined),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '筛选计划',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const ValueKey('closePlanFilterPanelButton'),
                  tooltip: '收起筛选',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                final useStackedFields =
                    constraints.maxWidth < 560 || textScale > 1.3;
                final fields = <Widget>[
                  _buildLevelField(),
                  _buildLifecycleField(),
                  _buildSortField(),
                ];

                if (useStackedFields) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      fields[0],
                      const SizedBox(height: AppSpacing.sm),
                      fields[1],
                      const SizedBox(height: AppSpacing.sm),
                      fields[2],
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: fields[1]),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: fields[2]),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            SwitchListTile(
              key: const ValueKey('planIncludeArchivedFilter'),
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.archive_outlined),
              title: const Text('显示归档'),
              subtitle: const Text('在当前目标列表中包含已归档项目'),
              value: filter.includeArchived,
              onChanged: (value) =>
                  onChanged(filter.copyWith(includeArchived: value)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelField() {
    return DropdownButtonFormField<String>(
      key: const ValueKey('planLevelFilter'),
      initialValue: filter.level?.name ?? 'all',
      isDense: true,
      isExpanded: true,
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
    );
  }

  Widget _buildLifecycleField() {
    return DropdownButtonFormField<PlanLifecycleFilter>(
      key: const ValueKey('planLifecycleFilter'),
      initialValue: filter.lifecycle,
      isDense: true,
      isExpanded: true,
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
    );
  }

  Widget _buildSortField() {
    return DropdownButtonFormField<PlanSortMode>(
      key: const ValueKey('planSortMode'),
      initialValue: filter.sortMode,
      isDense: true,
      isExpanded: true,
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
  PlanSortMode.createdAtDesc => '最近创建',
  PlanSortMode.levelThenPriority => '层级与优先级',
};
