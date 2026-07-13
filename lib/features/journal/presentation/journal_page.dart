import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
              onSave: (data) => _saveTodayEntry(ref, data),
            ),
            const Divider(height: 1),
            JournalHistoryList(
              state: historyState,
              onRetry: () async {
                try {
                  await ref.read(journalControllerProvider.notifier).reload();
                } catch (_) {
                  // The history widget continues to expose its local error state.
                }
              },
              onEntryTap: (historyEntry) {
                _showEntryDetail(context, historyEntry);
              },
            ),
          ],
        ),
      ),
    );
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

  Future<void> _showEntryDetail(BuildContext context, JournalEntry entry) {
    return showDialog<void>(
      context: context,
      builder: (context) => JournalEntryDetailDialog(entry: entry),
    );
  }
}
