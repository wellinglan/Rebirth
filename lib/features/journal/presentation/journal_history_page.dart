import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_repository.dart';

import 'journal_controller.dart';
import 'widgets/journal_entry_detail_dialog.dart';
import 'widgets/journal_history_list.dart';

class JournalHistoryPage extends ConsumerWidget {
  const JournalHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(journalControllerProvider);
    final today = ref.watch(dateTimeServiceProvider).currentLocalDateString();

    return SafeArea(
      key: const ValueKey('journalHistoryPage'),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('journalHistoryBackButton'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: '返回今日复盘',
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 4),
                Text('历史复盘', style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              child: JournalHistoryList(
                state: history,
                today: today,
                onRetry: () => _reload(ref),
                onEntryTap: (entry) => _showDetail(context, ref, entry, today),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reload(WidgetRef ref) async {
    try {
      await ref.read(journalControllerProvider.notifier).reload();
    } catch (_) {
      // The history page keeps its retryable error state visible.
    }
  }

  Future<void> _showDetail(
    BuildContext context,
    WidgetRef ref,
    JournalEntry entry,
    String today,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => JournalEntryDetailDialog(
        entry: entry,
        today: today,
        onEdit: () => context.push(RoutePaths.journalForDate(entry.entryDate)),
        onDelete: () => _confirmDelete(context, ref, entry),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    JournalEntry entry,
  ) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            key: const ValueKey('confirmDeleteJournalDialog'),
            title: const Text('删除这篇 Journal？'),
            content: const Text('记录会在本地隐藏，并在下次手动同步时把删除状态同步到其他设备。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                key: const ValueKey('confirmDeleteJournalButton'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(journalControllerProvider.notifier).deleteEntry(entry.id);
      ref.invalidate(journalEntryForDateProvider(entry.entryDate));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Journal 已删除，等待手动同步')));
    } on JournalConflictPendingException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('该 Journal 存在同步冲突，请先在设置的同步中心处理')),
        );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('删除失败，本地记录未改变')));
    }
  }
}
