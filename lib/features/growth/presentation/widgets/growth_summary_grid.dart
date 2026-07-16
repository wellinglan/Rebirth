import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/core/theme/app_typography.dart';
import 'package:rebirth/features/growth/domain/growth_snapshot.dart';

import '../growth_formatters.dart';

class GrowthSummaryGrid extends StatelessWidget {
  const GrowthSummaryGrid({required this.snapshot, super.key});

  final GrowthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final items = <_GrowthSummaryItem>[
      _GrowthSummaryItem(
        keyName: 'research',
        icon: Icons.science_outlined,
        label: '科研总时长',
        value: GrowthFormatters.duration(
          snapshot.researchSummary.recordedDayCount == 0
              ? null
              : snapshot.researchSummary.total,
        ),
      ),
      _GrowthSummaryItem(
        keyName: 'learning',
        icon: Icons.menu_book_outlined,
        label: '学习总时长',
        value: GrowthFormatters.duration(
          snapshot.learningSummary.recordedDayCount == 0
              ? null
              : snapshot.learningSummary.total,
        ),
      ),
      _GrowthSummaryItem(
        keyName: 'exercise',
        icon: Icons.directions_run_outlined,
        label: '运动总时长',
        value: GrowthFormatters.duration(
          snapshot.exerciseSummary.recordedDayCount == 0
              ? null
              : snapshot.exerciseSummary.total,
        ),
      ),
      _GrowthSummaryItem(
        keyName: 'sleep',
        icon: Icons.bedtime_outlined,
        label: '平均睡眠',
        value: GrowthFormatters.averageDuration(snapshot.sleepSummary.average),
      ),
      _GrowthSummaryItem(
        keyName: 'mood',
        icon: Icons.sentiment_satisfied_alt_outlined,
        label: '平均 Mood',
        value: GrowthFormatters.score(snapshot.moodSummary.average),
      ),
      _GrowthSummaryItem(
        keyName: 'energy',
        icon: Icons.bolt_outlined,
        label: '平均 Energy',
        value: GrowthFormatters.score(snapshot.energySummary.average),
      ),
      _GrowthSummaryItem(
        keyName: 'journal',
        icon: Icons.edit_note_outlined,
        label: 'Journal 记录',
        value: '${snapshot.journalRecordedDays} / ${snapshot.period.days} 天',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = switch (constraints.maxWidth) {
          < 300 => 1,
          < 540 => 2,
          < 760 => 3,
          _ => 4,
        };
        final width =
            (constraints.maxWidth - AppLayout.cardGap * (columns - 1)) /
            columns;

        return Wrap(
          spacing: AppLayout.cardGap,
          runSpacing: AppLayout.cardGap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Semantics(
                  label: '${item.label}，${item.value}',
                  container: true,
                  excludeSemantics: true,
                  child: Card(
                    key: ValueKey('growthSummary_${item.keyName}'),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            item.icon,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(item.label),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            item.value,
                            style: AppTypography.numericStyle(
                              Theme.of(context).textTheme.titleMedium!,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

final class _GrowthSummaryItem {
  const _GrowthSummaryItem({
    required this.keyName,
    required this.icon,
    required this.label,
    required this.value,
  });

  final String keyName;
  final IconData icon;
  final String label;
  final String value;
}
