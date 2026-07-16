import 'package:flutter/material.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';

import '../growth_formatters.dart';
import '../models/growth_chart_models.dart';
import 'growth_line_chart.dart';
import 'growth_section_card.dart';

class FocusTrendChart extends StatelessWidget {
  const FocusTrendChart({
    required this.research,
    required this.learning,
    required this.period,
    super.key,
  });

  final GrowthChartSeries research;
  final GrowthChartSeries learning;
  final GrowthPeriod period;

  @override
  Widget build(BuildContext context) {
    return GrowthSectionCard(
      cardKey: const ValueKey('growthFocusTrendCard'),
      title: '专注投入',
      subtitle: '科研与学习时间，单位为分钟',
      footer: Text(
        '科研记录 ${research.recordedPointCount} 天，总计 '
        '${GrowthFormatters.duration(research.hasRecordedValues ? research.total : null)}；'
        '学习记录 ${learning.recordedPointCount} 天，总计 '
        '${GrowthFormatters.duration(learning.hasRecordedValues ? learning.total : null)}',
        key: const ValueKey('growthFocusSummary'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      child: GrowthLineChart(
        period: period,
        semanticLabel:
            '科研记录 ${research.recordedPointCount} 天，学习记录 ${learning.recordedPointCount} 天',
        emptyMessage: '这一周期还没有科研或学习时间记录。',
        emptyKey: const ValueKey('growthFocusTrendEmpty'),
        chartKey: const ValueKey('growthFocusLineChart'),
        tooltipValue: (value) => GrowthFormatters.duration(value),
        yAxisValue: GrowthFormatters.minutesAxis,
        minimumRange: 60,
        series: [
          GrowthLineSeriesStyle(
            series: research,
            color: Theme.of(context).colorScheme.primary,
          ),
          GrowthLineSeriesStyle(
            series: learning,
            color: Theme.of(context).colorScheme.tertiary,
            dashArray: const [6, 4],
          ),
        ],
      ),
    );
  }
}
