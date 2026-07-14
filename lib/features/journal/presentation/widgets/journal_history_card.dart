import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_typography.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';

import 'journal_history_formatters.dart';

class JournalHistoryCard extends StatelessWidget {
  const JournalHistoryCard({
    required this.entry,
    required this.today,
    required this.onTap,
    super.key,
  });

  final JournalEntry entry;
  final String today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: ValueKey('journalHistoryItem_${entry.id}'),
      margin: const EdgeInsets.only(bottom: AppLayout.cardGap),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          entry.entryDate,
          style: AppTypography.numericStyle(theme.textTheme.titleSmall!),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.previewText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                journalHistoryStatusLabel(entry: entry, today: today),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
