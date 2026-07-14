import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_typography.dart';
import 'package:rebirth/features/health/domain/health_entry.dart';

import 'health_formatters.dart';

class HealthHistoryCard extends StatelessWidget {
  const HealthHistoryCard({required this.entry, required this.onTap, super.key});

  final HealthEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      '睡眠 ${formatHealthDuration(entry.sleepDurationMinutes)}',
      '运动 ${formatHealthDuration(entry.exerciseDurationMinutes)}',
      '饮水 ${entry.waterIntakeMl == null ? '未填写' : '${entry.waterIntakeMl} ml'}',
      '体重 ${formatHealthWeight(entry.weightKg)}',
      if (entry.physicalStateScore != null)
        '身体状态 ${entry.physicalStateScore}/5',
    ];

    return Card(
      child: ListTile(
        key: ValueKey('healthHistory-${entry.id}'),
        onTap: onTap,
        title: Text(
          entry.recordDate,
          style: AppTypography.numericStyle(
            Theme.of(context).textTheme.titleSmall!,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(details.join(' · ')),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
