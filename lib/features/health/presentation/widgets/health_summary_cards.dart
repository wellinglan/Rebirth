import 'package:flutter/material.dart';
import 'package:rebirth/features/health/domain/health_summary.dart';

import 'health_formatters.dart';

class HealthSummaryCards extends StatelessWidget {
  const HealthSummaryCards({required this.summary, super.key});

  final HealthSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label, String value})>[
      (
        icon: Icons.bedtime_outlined,
        label: '平均睡眠',
        value: summary.averageSleepMinutes == null
            ? '暂无数据'
            : formatHealthDuration(summary.averageSleepMinutes!.round()),
      ),
      (
        icon: Icons.directions_run_outlined,
        label: '总运动',
        value: summary.totalExerciseMinutes == null
            ? '暂无数据'
            : formatHealthDuration(summary.totalExerciseMinutes),
      ),
      (
        icon: Icons.water_drop_outlined,
        label: '平均饮水',
        value: summary.averageWaterIntakeMl == null
            ? '暂无数据'
            : '${summary.averageWaterIntakeMl!.round()} ml',
      ),
      (
        icon: Icons.monitor_weight_outlined,
        label: '最新体重',
        value: summary.latestWeightKg == null
            ? '暂无数据'
            : formatHealthWeight(summary.latestWeightKg),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 520
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(item.icon),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.label),
                              const SizedBox(height: 4),
                              Text(
                                item.value,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
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
