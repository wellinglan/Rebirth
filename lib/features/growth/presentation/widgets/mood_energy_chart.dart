import 'package:flutter/material.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';

import '../growth_formatters.dart';
import '../models/growth_chart_models.dart';
import 'growth_line_chart.dart';
import 'growth_section_card.dart';

class MoodEnergyChart extends StatelessWidget {
  const MoodEnergyChart({
    required this.mood,
    required this.energy,
    required this.period,
    super.key,
  });

  final GrowthChartSeries mood;
  final GrowthChartSeries energy;
  final GrowthPeriod period;

  @override
  Widget build(BuildContext context) {
    return GrowthSectionCard(
      cardKey: const ValueKey('growthMoodEnergyCard'),
      title: 'Mood 与 Energy',
      subtitle: '评分范围为 1–10',
      footer: Text(
        'Mood 记录 ${mood.recordedPointCount} 天，平均 '
        '${GrowthFormatters.score(mood.average)}；'
        'Energy 记录 ${energy.recordedPointCount} 天，平均 '
        '${GrowthFormatters.score(energy.average)}',
        key: const ValueKey('growthMoodEnergySummary'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      child: GrowthLineChart(
        period: period,
        semanticLabel:
            'Mood 与 Energy 评分范围 1 到 10，Mood 记录 '
            '${mood.recordedPointCount} 天，Energy 记录 '
            '${energy.recordedPointCount} 天',
        emptyMessage: '这一周期还没有 Mood 或 Energy 评分记录。',
        emptyKey: const ValueKey('growthMoodEnergyEmpty'),
        chartKey: const ValueKey('growthMoodEnergyLineChart'),
        tooltipValue: GrowthFormatters.scorePoint,
        yAxisValue: (value) => value.round().toString(),
        minY: 1,
        fixedMaxY: 10,
        series: [
          GrowthLineSeriesStyle(
            series: mood,
            color: Theme.of(context).colorScheme.primary,
          ),
          GrowthLineSeriesStyle(
            series: energy,
            color: Theme.of(context).colorScheme.tertiary,
            dashArray: const [6, 4],
          ),
        ],
      ),
    );
  }
}
