import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';

import 'today_history_controller.dart';
import 'widgets/today_entry_detail_dialog.dart';
import 'widgets/today_history_list.dart';

class TodayHistoryPage extends ConsumerWidget {
  const TodayHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(todayHistoryControllerProvider);

    return SafeArea(
      key: const ValueKey('todayHistoryPage'),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('todayHistoryBackButton'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: '返回今日',
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 4),
                Text('历史记录', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: history.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  key: ValueKey('todayHistoryLoadingState'),
                ),
              ),
              error: (error, stackTrace) => Center(
                child: Column(
                  key: const ValueKey('todayHistoryErrorState'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('历史记录暂时无法加载'),
                    const SizedBox(height: 12),
                    IconButton(
                      onPressed: () async {
                        try {
                          await ref
                              .read(todayHistoryControllerProvider.notifier)
                              .reload();
                        } catch (_) {
                          // The page keeps displaying its retryable error state.
                        }
                      },
                      tooltip: '重新加载历史记录',
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              data: (entries) => entries.isEmpty
                  ? const Center(
                      child: Text(
                        '还没有历史记录',
                        key: ValueKey('todayHistoryEmptyState'),
                      ),
                    )
                  : TodayHistoryList(
                      entries: entries,
                      onEntryTap: (entry) => _showDetail(context, entry),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetail(BuildContext context, TodayEntry entry) {
    return showDialog<void>(
      context: context,
      builder: (context) => TodayEntryDetailDialog(entry: entry),
    );
  }
}
