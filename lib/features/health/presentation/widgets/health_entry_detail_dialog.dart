import 'package:flutter/material.dart';
import 'package:rebirth/features/health/domain/health_entry.dart';

import 'health_formatters.dart';

class HealthEntryDetailDialog extends StatelessWidget {
  const HealthEntryDetailDialog({
    required this.entry,
    this.onDelete,
    super.key,
  });

  final HealthEntry entry;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, String value})>[
      (label: '日期', value: entry.recordDate),
      (label: '睡眠', value: formatHealthDuration(entry.sleepDurationMinutes)),
      (label: '睡眠描述', value: entry.sleepDescription ?? '未填写'),
      (label: '体重', value: formatHealthWeight(entry.weightKg)),
      (label: '体重描述', value: entry.weightDescription ?? '未填写'),
      (
        label: '饮水',
        value: entry.waterIntakeMl == null
            ? '未填写'
            : '${entry.waterIntakeMl} ml',
      ),
      (label: '饮水描述', value: entry.waterDescription ?? '未填写'),
      (
        label: '运动时长',
        value: formatHealthDuration(entry.exerciseDurationMinutes),
      ),
      (label: '运动描述', value: entry.exerciseDescription ?? '未填写'),
      (label: '运动类型', value: entry.exerciseType ?? '未填写'),
      (
        label: '身体状态',
        value: entry.physicalStateScore == null
            ? '未填写'
            : '${entry.physicalStateScore}/10',
      ),
      (label: '身体感受', value: entry.physicalStateDescription ?? '未填写'),
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
        if (onDelete != null)
          TextButton.icon(
            key: const ValueKey('deleteHealthFromHistoryButton'),
            onPressed: () {
              Navigator.of(context).pop();
              onDelete!();
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('删除'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
