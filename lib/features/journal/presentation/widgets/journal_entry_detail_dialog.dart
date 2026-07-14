import 'package:flutter/material.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';

import 'journal_history_formatters.dart';

class JournalEntryDetailDialog extends StatelessWidget {
  const JournalEntryDetailDialog({
    required this.entry,
    required this.today,
    super.key,
  });

  final JournalEntry entry;
  final String today;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('journalEntryDetailDialog'),
      title: Text(entry.entryDate),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailAnswer(
                question: '今天最重要的完成是什么？',
                answer: entry.mostImportantAccomplishment,
              ),
              _DetailAnswer(
                question: '今天最消耗我的事情是什么？',
                answer: entry.mostDrainingEvent,
              ),
              _DetailAnswer(
                question: '今天主要情绪的来源是什么？',
                answer: entry.emotionSource,
              ),
              _DetailAnswer(question: '今天我学到了什么？', answer: entry.learning),
              _DetailAnswer(
                question: '明天我想如何调整？',
                answer: entry.tomorrowAdjustment,
              ),
              Text(
                journalHistoryStatusLabel(entry: entry, today: today),
                style: Theme.of(context).textTheme.labelLarge,
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

class _DetailAnswer extends StatelessWidget {
  const _DetailAnswer({required this.question, required this.answer});

  final String question;
  final String? answer;

  @override
  Widget build(BuildContext context) {
    final text = answer?.trim();
    final isEmpty = text == null || text.isEmpty;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isEmpty ? '未填写' : text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w400,
              color: isEmpty ? theme.colorScheme.onSurfaceVariant : null,
            ),
          ),
        ],
      ),
    );
  }
}
