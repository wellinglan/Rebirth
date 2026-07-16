import 'package:flutter/material.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';

import '../growth_formatters.dart';
import '../models/growth_chart_models.dart';
import 'growth_line_chart.dart';
import 'growth_section_card.dart';

class SleepTrendChart extends StatelessWidget {
  const SleepTrendChart({required this.sleep, required this.period, super.key});

  final GrowthChartSeries sleep;
  final GrowthPeriod period;

  @override
  Widget build(BuildContext context) {
    return GrowthSectionCard(
      cardKey: const ValueKey('growthSleepTrendCard'),
      title: '睡眠趋势',
      subtitle: '纵轴按小时展示，底层仍为分钟',
      footer: Text(
        '睡眠记录 ${sleep.recordedPointCount} 天，平均 '
        '${GrowthFormatters.averageDuration(sleep.average)}',
        key: const ValueKey('growthSleepSummary'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      child: GrowthLineChart(
        period: period,
        semanticLabel:
            '睡眠记录 ${sleep.recordedPointCount} 天，平均 ${GrowthFormatters.averageDuration(sleep.average)}',
        emptyMessage: '这一周期还没有睡眠时长记录。',
        emptyKey: const ValueKey('growthSleepTrendEmpty'),
        chartKey: const ValueKey('growthSleepLineChart'),
        tooltipValue: (value) => GrowthFormatters.duration(value),
        yAxisValue: GrowthFormatters.sleepAxis,
        minimumRange: 60,
        series: [
          GrowthLineSeriesStyle(
            series: sleep,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ],
      ),
    );
  }
}
