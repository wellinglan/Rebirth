import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';

import '../growth_formatters.dart';
import '../models/growth_chart_models.dart';
import 'growth_section_card.dart';

class JournalCoverageGrid extends StatelessWidget {
  const JournalCoverageGrid({
    required this.days,
    required this.recordedDays,
    required this.completedDays,
    super.key,
  });

  final List<GrowthJournalDay> days;
  final int recordedDays;
  final int completedDays;

  @override
  Widget build(BuildContext context) {
    return GrowthSectionCard(
      cardKey: const ValueKey('growthJournalCoverage'),
      title: '记录覆盖',
      subtitle: 'Journal 内容记录状态',
      footer: Text(
        '已记录 $recordedDays / ${days.length} 天 · '
        '已完成 $completedDays / ${days.length} 天',
        key: const ValueKey('growthJournalCounts'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [for (final day in days) _JournalDayCell(day: day)],
          ),
          const SizedBox(height: AppSpacing.md),
          const Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              _JournalLegend(
                status: GrowthJournalDayStatus.missing,
                label: '未记录',
              ),
              _JournalLegend(
                status: GrowthJournalDayStatus.recordedDraft,
                label: '已记录',
              ),
              _JournalLegend(
                status: GrowthJournalDayStatus.completed,
                label: '已完成',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JournalDayCell extends StatelessWidget {
  const _JournalDayCell({required this.day});

  final GrowthJournalDay day;

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(context, day.status);
    final statusLabel = _labelFor(day.status);
    final dateLabel = GrowthFormatters.tooltipDate(day.date);

    return Semantics(
      label: '$dateLabel，$statusLabel',
      container: true,
      excludeSemantics: true,
      child: Tooltip(
        message: '$dateLabel · $statusLabel',
        child: Container(
          key: ValueKey('growthJournalDay_${day.date}'),
          width: 48,
          height: 52,
          decoration: BoxDecoration(
            color: visual.background,
            border: Border.all(color: visual.border),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(visual.icon, size: 17, color: visual.foreground),
              const SizedBox(height: 2),
              Text(
                day.date.substring(8, 10),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: visual.foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JournalLegend extends StatelessWidget {
  const _JournalLegend({required this.status, required this.label});

  final GrowthJournalDayStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(context, status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: visual.background,
            border: Border.all(color: visual.border),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(visual.icon, size: 14, color: visual.foreground),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(label),
      ],
    );
  }
}

({Color background, Color border, Color foreground, IconData icon}) _visualFor(
  BuildContext context,
  GrowthJournalDayStatus status,
) {
  final colors = Theme.of(context).colorScheme;
  return switch (status) {
    GrowthJournalDayStatus.missing => (
      background: colors.surface,
      border: colors.outlineVariant,
      foreground: colors.onSurfaceVariant,
      icon: Icons.remove,
    ),
    GrowthJournalDayStatus.recordedDraft => (
      background: colors.tertiaryContainer,
      border: colors.tertiary,
      foreground: colors.onTertiaryContainer,
      icon: Icons.edit_outlined,
    ),
    GrowthJournalDayStatus.completed => (
      background: colors.primaryContainer,
      border: colors.primary,
      foreground: colors.onPrimaryContainer,
      icon: Icons.check,
    ),
  };
}

String _labelFor(GrowthJournalDayStatus status) {
  return switch (status) {
    GrowthJournalDayStatus.missing => '未记录',
    GrowthJournalDayStatus.recordedDraft => '有内容，尚未完成',
    GrowthJournalDayStatus.completed => '有内容，已完成',
  };
}
