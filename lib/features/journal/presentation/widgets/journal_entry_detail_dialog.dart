import 'package:flutter/material.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';

import 'journal_history_formatters.dart';

class JournalEntryDetailDialog extends StatelessWidget {
  const JournalEntryDetailDialog({
    required this.entry,
    required this.today,
    this.onDelete,
    super.key,
  });

  final JournalEntry entry;
  final String today;
  final VoidCallback? onDelete;

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
              for (final item in entry.promptItems)
                _DetailAnswer(
                  question: item.questionTextSnapshot,
                  answer: item.answerText,
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
        if (onDelete != null)
          TextButton.icon(
            key: const ValueKey('deleteJournalFromHistoryButton'),
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
