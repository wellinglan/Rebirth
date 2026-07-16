import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';

import '../growth_formatters.dart';
import '../models/growth_chart_models.dart';
import 'growth_section_card.dart';

class ExerciseTrendChart extends StatelessWidget {
  const ExerciseTrendChart({
    required this.exercise,
    required this.period,
    super.key,
  });

  final GrowthChartSeries exercise;
  final GrowthPeriod period;

  @override
  Widget build(BuildContext context) {
    return GrowthSectionCard(
      cardKey: const ValueKey('growthExerciseTrendCard'),
      title: '运动趋势',
      subtitle: '每日运动总时长，单位为分钟',
      footer: Text(
        '运动记录 ${exercise.recordedPointCount} 天，总计 '
        '${GrowthFormatters.duration(exercise.hasRecordedValues ? exercise.total : null)}',
        key: const ValueKey('growthExerciseSummary'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      child: exercise.hasRecordedValues
          ? _ExerciseBarChart(exercise: exercise, period: period)
          : const Padding(
              key: ValueKey('growthExerciseTrendEmpty'),
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text('这一周期还没有运动时间记录。', textAlign: TextAlign.center),
            ),
    );
  }
}

class _ExerciseBarChart extends StatelessWidget {
  const _ExerciseBarChart({required this.exercise, required this.period});

  final GrowthChartSeries exercise;
  final GrowthPeriod period;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final largest = exercise.points
        .map((point) => point.value)
        .whereType<int>()
        .fold<int>(0, math.max);
    final maxY = math.max(30.0, largest * 1.15);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 14, height: 14, color: colors.primary),
            const SizedBox(width: AppSpacing.xs),
            const Text('运动'),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          label:
              '运动记录 ${exercise.recordedPointCount} 天，总计 ${GrowthFormatters.duration(exercise.total)}',
          image: true,
          container: true,
          child: ExcludeSemantics(
            child: SizedBox(
              key: const ValueKey('growthExerciseBarChart'),
              height: 230,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: colors.outlineVariant.withValues(alpha: 0.7),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      left: BorderSide(color: colors.outlineVariant),
                      bottom: BorderSide(color: colors.outlineVariant),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          meta: meta,
                          space: AppSpacing.xs,
                          child: Text(
                            GrowthFormatters.minutesAxis(value),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (value != index ||
                              !GrowthFormatters.showAxisLabel(
                                index: index,
                                pointCount: exercise.points.length,
                                period: period,
                              )) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            space: AppSpacing.xs,
                            child: Text(
                              GrowthFormatters.axisDate(
                                exercise.points[index].date,
                              ),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipColor: (_) => colors.inverseSurface,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final point = exercise.points[group.x];
                        return BarTooltipItem(
                          '${GrowthFormatters.tooltipDate(point.date)}\n'
                          '${GrowthFormatters.duration(point.value)}',
                          TextStyle(color: colors.onInverseSurface),
                        );
                      },
                    ),
                  ),
                  barGroups: [
                    for (final point in exercise.points)
                      BarChartGroupData(
                        x: point.index,
                        barRods: point.value == null
                            ? const []
                            : [
                                BarChartRodData(
                                  toY: point.value!.toDouble(),
                                  width: period == GrowthPeriod.sevenDays
                                      ? 18
                                      : 6,
                                  color: colors.primary,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(3),
                                  ),
                                ),
                              ],
                      ),
                  ],
                ),
                duration: Duration.zero,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
