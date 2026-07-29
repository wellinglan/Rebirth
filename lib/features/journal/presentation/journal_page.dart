import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_save_data.dart';

import 'journal_controller.dart';
import 'journal_prompt_controller.dart';
import 'journal_today_controller.dart';
import 'widgets/journal_entry_detail_dialog.dart';
import 'widgets/journal_form.dart';
import 'widgets/journal_history_list.dart';

class JournalPage extends ConsumerStatefulWidget {
  const JournalPage({this.targetDate, super.key});

  final String? targetDate;

  @override
  ConsumerState<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends ConsumerState<JournalPage> {
  String? _handledTargetDate;

  @override
  void didUpdateWidget(covariant JournalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetDate != widget.targetDate) {
      _handledTargetDate = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final journalState = ref.watch(journalTodayControllerProvider);
    final promptState = ref.watch(journalPromptControllerProvider);
    final historyState = ref.watch(journalControllerProvider);
    final dateTimeService = ref.watch(dateTimeServiceProvider);
    final today = dateTimeService.currentLocalDateString();
    final targetDate = widget.targetDate;
    final targetDateIsValid =
        targetDate == null ||
        dateTimeService.isValidLocalDateString(targetDate);
    final targetEntry = targetDate != null && targetDateIsValid
        ? ref.watch(journalEntryForDateProvider(targetDate))
        : null;
    final matchedEntry = targetEntry?.asData?.value;
    if (matchedEntry != null && matchedEntry.entryDate == targetDate) {
      _scheduleTargetDialog(matchedEntry, today);
    }

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
            if (targetDate != null)
              _JournalTargetNotice(
                targetDate: targetDate,
                isValid: targetDateIsValid,
                state: targetEntry,
              ),
            if (entry == null && promptState.isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(
                    key: ValueKey('journalPromptFormLoadingState'),
                  ),
                ),
              )
            else if (entry == null && promptState.hasError)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('复盘问题暂时无法加载'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => ref
                            .read(journalPromptControllerProvider.notifier)
                            .reload(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              )
            else
              JournalForm(
                entry: entry,
                recordDate: entry?.entryDate ?? today,
                prompts: promptState.asData?.value.activePrompts ?? const [],
                onSaveDraft: (data) =>
                    _saveTodayEntry(ref, data, complete: false),
                onComplete: (data) =>
                    _saveTodayEntry(ref, data, complete: true),
                onReopen: entry == null ? null : () => _reopenTodayEntry(ref),
                onApplyLatestPrompts: entry?.status == JournalEntryStatus.draft
                    ? () => _applyLatestPrompts(ref)
                    : null,
                onManagePrompts: () => context.push(RoutePaths.journalPrompts),
                onDelete: entry == null
                    ? null
                    : () => _confirmDelete(context, entry),
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

  Future<void> _saveTodayEntry(
    WidgetRef ref,
    JournalSaveData data, {
    required bool complete,
  }) async {
    final controller = ref.read(journalTodayControllerProvider.notifier);
    if (complete) {
      await controller.completeReflection(data);
    } else {
      await controller.saveDraft(data);
    }
    await _reloadJournalHistory(ref);
  }

  Future<void> _reopenTodayEntry(WidgetRef ref) async {
    await ref.read(journalTodayControllerProvider.notifier).reopen();
    await _reloadJournalHistory(ref);
  }

  Future<JournalEntry> _applyLatestPrompts(WidgetRef ref) async {
    final saved = await ref
        .read(journalTodayControllerProvider.notifier)
        .applyLatestPrompts();
    await _reloadJournalHistory(ref);
    return saved;
  }

  Future<void> _reloadJournalHistory(WidgetRef ref) async {
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
      builder: (context) => JournalEntryDetailDialog(
        entry: entry,
        today: today,
        onDelete: () => _confirmDelete(this.context, entry),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, JournalEntry entry) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            key: const ValueKey('confirmDeleteJournalDialog'),
            title: const Text('删除这篇 Journal？'),
            content: const Text('记录会在本地隐藏，并在下次手动同步时把删除状态同步到其他设备。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                key: const ValueKey('confirmDeleteJournalButton'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    try {
      await ref.read(journalControllerProvider.notifier).deleteEntry(entry.id);
      await ref.read(journalTodayControllerProvider.notifier).reload();
      ref.invalidate(journalEntryForDateProvider(entry.entryDate));
      if (!mounted) return;
      ScaffoldMessenger.of(this.context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Journal 已删除，等待手动同步')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(this.context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('删除失败，本地记录未改变')));
    }
  }

  void _scheduleTargetDialog(JournalEntry entry, String today) {
    if (_handledTargetDate == entry.entryDate) return;
    _handledTargetDate = entry.entryDate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showEntryDetail(context, entry, today);
    });
  }
}

class _JournalTargetNotice extends StatelessWidget {
  const _JournalTargetNotice({
    required this.targetDate,
    required this.isValid,
    required this.state,
  });

  final String targetDate;
  final bool isValid;
  final AsyncValue<JournalEntry?>? state;

  @override
  Widget build(BuildContext context) {
    final message = !isValid
        ? '日期参数无效，无法定位 Journal 记录。'
        : state?.when(
                loading: () => '正在查找 $targetDate 的 Journal 记录...',
                error: (error, stackTrace) => '$targetDate 的 Journal 记录暂时无法读取。',
                data: (entry) => entry?.entryDate == targetDate
                    ? '已定位 $targetDate 的 Journal 记录。'
                    : '未找到 $targetDate 的 Journal 记录。',
              ) ??
              '日期参数无效，无法定位 Journal 记录。';
    return Container(
      key: const ValueKey('journalTargetNotice'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(message),
    );
  }
}
