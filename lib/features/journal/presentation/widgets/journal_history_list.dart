import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';

import 'journal_history_card.dart';

class JournalHistoryList extends StatelessWidget {
  const JournalHistoryList({
    required this.state,
    required this.today,
    required this.onRetry,
    required this.onEntryTap,
    super.key,
  });

  final AsyncValue<List<JournalEntry>> state;
  final String today;
  final VoidCallback onRetry;
  final ValueChanged<JournalEntry> onEntryTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppLayout.pagePadding.copyWith(top: AppLayout.sectionGap),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.maxContentWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('最近复盘', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              state.when(
                loading: () => const Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      key: ValueKey('journalHistoryLoadingState'),
                      strokeWidth: 2,
                    ),
                  ),
                ),
                error: (error, stackTrace) => Row(
                  key: const ValueKey('journalHistoryErrorState'),
                  children: [
                    const Expanded(child: Text('历史复盘暂时无法加载')),
                    IconButton(
                      onPressed: onRetry,
                      tooltip: '重新加载历史复盘',
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                data: (entries) => entries.isEmpty
                    ? const Text(
                        '还没有历史复盘',
                        key: ValueKey('journalHistoryEmptyState'),
                      )
                    : Column(
                        key: const ValueKey('journalHistoryList'),
                        children: [
                          for (final entry in entries)
                            JournalHistoryCard(
                              entry: entry,
                              today: today,
                              onTap: () => onEntryTap(entry),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
