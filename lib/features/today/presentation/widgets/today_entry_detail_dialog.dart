import 'package:flutter/material.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';

import 'today_history_formatters.dart';

class TodayEntryDetailDialog extends StatelessWidget {
  const TodayEntryDetailDialog({required this.entry, super.key});

  final TodayEntry entry;

  @override
  Widget build(BuildContext context) {
    final health = entry.health;

    return AlertDialog(
      key: const ValueKey('todayEntryDetailDialog'),
      title: Text(entry.recordDate),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('三件事', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (var index = 0; index < entry.priorities.length; index++)
                _PriorityDetail(
                  index: index,
                  priority: entry.priorities[index],
                ),
              const SizedBox(height: 18),
              _DetailValue(label: 'Mood', value: _score(entry.moodScore)),
              _DetailValue(label: 'Energy', value: _score(entry.energyScore)),
              _DetailValue(
                label: '科研时间',
                value: formatDurationMinutes(entry.researchMinutes),
              ),
              _DetailValue(
                label: '学习时间',
                value: formatDurationMinutes(entry.learningMinutes),
              ),
              _DetailValue(label: '今日一句话', value: _text(entry.dailyNote)),
              _DetailValue(
                label: '睡眠时长',
                value: formatDurationMinutes(health?.sleepDurationMinutes),
              ),
              _DetailValue(
                label: '运动时长',
                value: formatDurationMinutes(health?.exerciseDurationMinutes),
              ),
              _DetailValue(
                label: '身体状态',
                value: _score(health?.physicalStateScore),
              ),
              _DetailValue(
                label: '记录状态',
                value: entry.status == TodayRecordStatus.completed
                    ? '已完成'
                    : '草稿',
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

  String _score(int? score) => score?.toString() ?? '未填写';

  String _text(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? '未填写' : text;
  }
}

class _PriorityDetail extends StatelessWidget {
  const _PriorityDetail({required this.index, required this.priority});

  final int index;
  final TodayPriority priority;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            priority.isPopulated && priority.completed
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              priority.isPopulated
                  ? priority.text!.trim()
                  : '第 ${index + 1} 项未填写',
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailValue extends StatelessWidget {
  const _DetailValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isEmpty = value == '未填写';
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: theme.textTheme.labelLarge),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isEmpty ? theme.colorScheme.onSurfaceVariant : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
