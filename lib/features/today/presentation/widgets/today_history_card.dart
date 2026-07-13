import 'package:flutter/material.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';

import 'today_history_formatters.dart';

class TodayHistoryCard extends StatelessWidget {
  const TodayHistoryCard({required this.entry, required this.onTap, super.key});

  final TodayEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priorities = entry.priorities
        .where((priority) => priority.isPopulated)
        .toList(growable: false);

    return Card(
      key: ValueKey('todayHistoryItem_${entry.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(entry.recordDate),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final priority in priorities.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        priority.completed
                            ? Icons.check_circle_outline
                            : Icons.radio_button_unchecked,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          priority.text!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (priorities.isEmpty)
                Text(
                  '未填写三件事',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              const SizedBox(height: 4),
              Text(
                'Mood ${entry.moodScore ?? '未填写'} · '
                'Energy ${entry.energyScore ?? '未填写'}',
              ),
              Text(
                '科研 ${formatDurationMinutes(entry.researchMinutes)} · '
                '学习 ${formatDurationMinutes(entry.learningMinutes)}',
              ),
              if (entry.dailyNote?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 6),
                Text(
                  entry.dailyNote!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
