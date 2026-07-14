import 'package:flutter/material.dart';
import 'package:rebirth/features/health/domain/health_entry.dart';

import 'health_formatters.dart';

class HealthEntryDetailDialog extends StatelessWidget {
  const HealthEntryDetailDialog({required this.entry, super.key});

  final HealthEntry entry;

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, String value})>[
      (label: '日期', value: entry.recordDate),
      (label: '睡眠', value: formatHealthDuration(entry.sleepDurationMinutes)),
      (label: '体重', value: formatHealthWeight(entry.weightKg)),
      (
        label: '饮水',
        value: entry.waterIntakeMl == null
            ? '未填写'
            : '${entry.waterIntakeMl} ml',
      ),
      (
        label: '运动时长',
        value: formatHealthDuration(entry.exerciseDurationMinutes),
      ),
      (label: '运动类型', value: entry.exerciseType ?? '未填写'),
      (
        label: '身体状态',
        value: entry.physicalStateScore == null
            ? '未填写'
            : '${entry.physicalStateScore}/5',
      ),
      (label: '备注', value: entry.note ?? '未填写'),
    ];

    return AlertDialog(
      key: const ValueKey('healthEntryDetailDialog'),
      title: const Text('健康记录详情'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 88,
                        child: Text(
                          row.label,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      Expanded(child: Text(row.value)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
