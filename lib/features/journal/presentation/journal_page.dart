import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_save_data.dart';

import 'journal_controller.dart';
import 'journal_today_controller.dart';
import 'widgets/journal_entry_detail_dialog.dart';
import 'widgets/journal_form.dart';
import 'widgets/journal_history_list.dart';

class JournalPage extends ConsumerWidget {
  const JournalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journalState = ref.watch(journalTodayControllerProvider);
    final historyState = ref.watch(journalControllerProvider);
    final today = ref.watch(dateTimeServiceProvider).currentLocalDateString();

    return SafeArea(
      child: journalState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            key: ValueKey('journalLoadingState'),
          ),
        ),
        error: (error, stackTrace) => Center(
          child: Column(
            key: const ValueKey('journalErrorState'),
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('今日复盘暂时无法加载'),
              const SizedBox(height: 12),
              IconButton(
                onPressed: () =>
                    ref.read(journalTodayControllerProvider.notifier).reload(),
                tooltip: '重新加载',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        data: (entry) => ListView(
          children: [
            JournalForm(
              entry: entry,
              recordDate: entry?.entryDate ?? today,
              onSave: (data) => _saveTodayEntry(ref, data),
              onOpenDailyInsight: (recordDate, hasUnsavedChanges) =>
                  _openDailyInsight(
                    context,
                    recordDate,
                    hasUnsavedChanges: hasUnsavedChanges,
                  ),
            ),
            const Divider(height: 1),
            JournalHistoryList(
              state: historyState,
              today: today,
              onRetry: () async {
                try {
                  await ref.read(journalControllerProvider.notifier).reload();
                } catch (_) {
                  // The history widget continues to expose its local error state.
                }
              },
              onEntryTap: (historyEntry) {
                _showEntryDetail(context, historyEntry, today);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDailyInsight(
    BuildContext context,
    String recordDate, {
    required bool hasUnsavedChanges,
  }) async {
    if (hasUnsavedChanges) {
      final continueWithSaved =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              key: const ValueKey('journalUnsavedDailyInsightDialog'),
              title: const Text('存在未保存的复盘修改'),
              content: const Text(
                '每日洞察只读取已经保存的 Journal 记录。请先保存，或继续使用上一次已保存的内容。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('返回保存'),
                ),
                FilledButton(
                  key: const ValueKey('continueWithSavedJournalButton'),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('使用已保存内容'),
                ),
              ],
            ),
          ) ??
          false;
      if (!continueWithSaved || !context.mounted) return;
    }
    await context.push(RoutePaths.aiCoachDaily(recordDate));
  }

  Future<void> _saveTodayEntry(WidgetRef ref, JournalSaveData data) async {
    await ref
        .read(journalTodayControllerProvider.notifier)
        .saveTodayEntry(data);
    try {
      await ref.read(journalControllerProvider.notifier).reload();
    } catch (_) {
      // The save succeeded; the history area exposes its own retry state.
    }
  }

  Future<void> _showEntryDetail(
    BuildContext context,
    JournalEntry entry,
    String today,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) =>
          JournalEntryDetailDialog(entry: entry, today: today),
    );
  }
}
