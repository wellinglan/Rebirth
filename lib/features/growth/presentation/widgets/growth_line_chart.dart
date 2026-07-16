import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';

import '../growth_formatters.dart';
import '../models/growth_chart_models.dart';

final class GrowthLineSeriesStyle {
  const GrowthLineSeriesStyle({
    required this.series,
    required this.color,
    this.dashArray,
  });

  final GrowthChartSeries series;
  final Color color;
  final List<int>? dashArray;
}

class GrowthLineChart extends StatelessWidget {
  const GrowthLineChart({
    required this.series,
    required this.period,
    required this.semanticLabel,
    required this.emptyMessage,
    required this.emptyKey,
    required this.chartKey,
    required this.tooltipValue,
    required this.yAxisValue,
    this.minY = 0,
    this.fixedMaxY,
    this.minimumRange = 1,
    super.key,
  });

  final List<GrowthLineSeriesStyle> series;
  final GrowthPeriod period;
  final String semanticLabel;
  final String emptyMessage;
  final Key emptyKey;
  final Key chartKey;
  final String Function(int value) tooltipValue;
  final String Function(double value) yAxisValue;
  final double minY;
  final double? fixedMaxY;
  final double minimumRange;

  @override
  Widget build(BuildContext context) {
    final hasData = series.any((item) => item.series.hasRecordedValues);
    if (!hasData) {
      return Padding(
        key: emptyKey,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Text(emptyMessage, textAlign: TextAlign.center),
      );
    }

    final colors = Theme.of(context).colorScheme;
    final pointCount = series.first.series.points.length;
    final recordedValues = series
        .expand((item) => item.series.points)
        .map((point) => point.value)
        .whereType<int>();
    final largest = recordedValues.fold<int>(0, math.max);
    final maxY = fixedMaxY ?? math.max(minY + minimumRange, largest * 1.15);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: [for (final item in series) _LineLegend(item: item)],
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          label: semanticLabel,
          image: true,
          container: true,
          child: ExcludeSemantics(
            child: SizedBox(
              key: chartKey,
              height: 230,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (pointCount - 1).toDouble(),
                  minY: minY,
                  maxY: maxY,
                  clipData: const FlClipData.all(),
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
                            yAxisValue(value),
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
                                pointCount: pointCount,
                                period: period,
                              )) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            space: AppSpacing.xs,
                            child: Text(
                              GrowthFormatters.axisDate(
                                series.first.series.points[index].date,
                              ),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipColor: (_) => colors.inverseSurface,
                      getTooltipItems: (spots) => spots
                          .map((spot) {
                            final styledSeries = series[spot.barIndex];
                            final point =
                                styledSeries.series.points[spot.x.round()];
                            return LineTooltipItem(
                              '${GrowthFormatters.tooltipDate(point.date)}\n'
                              '${styledSeries.series.label} '
                              '${tooltipValue(point.value!)}',
                              TextStyle(color: colors.onInverseSurface),
                            );
                          })
                          .toList(growable: false),
                    ),
                  ),
                  lineBarsData: [
                    for (final item in series)
                      LineChartBarData(
                        spots: item.series.points
                            .map((point) {
                              final value = point.value;
                              return value == null
                                  ? FlSpot.nullSpot
                                  : FlSpot(
                                      point.index.toDouble(),
                                      value.toDouble(),
                                    );
                            })
                            .toList(growable: false),
                        isCurved: false,
                        color: item.color,
                        barWidth: 2.4,
                        dashArray: item.dashArray,
                        dotData: FlDotData(
                          show: period == GrowthPeriod.sevenDays,
                        ),
                        belowBarData: BarAreaData(show: false),
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

class _LineLegend extends StatelessWidget {
  const _LineLegend({required this.item});

  final GrowthLineSeriesStyle item;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          child: item.dashArray == null
              ? Container(height: 3, color: item.color)
              : Row(
                  children: [
                    Expanded(child: Container(height: 3, color: item.color)),
                    const SizedBox(width: 3),
                    Expanded(child: Container(height: 3, color: item.color)),
                  ],
                ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(item.series.label),
      ],
    );
  }
}
