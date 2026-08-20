import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_repository.dart';
import 'package:rebirth/features/journal/domain/journal_save_data.dart';

import 'journal_controller.dart';
import 'journal_prompt_controller.dart';
import 'journal_today_controller.dart';
import 'widgets/journal_form.dart';

class JournalPage extends ConsumerStatefulWidget {
  const JournalPage({this.targetDate, super.key});

  final String? targetDate;

  @override
  ConsumerState<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends ConsumerState<JournalPage> {
  JournalEntry? _historicalEntry;

  @override
  void didUpdateWidget(covariant JournalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetDate != widget.targetDate) {
      _historicalEntry = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetDate = widget.targetDate;
    if (targetDate != null) return _buildHistoricalEditor(targetDate);
    return _buildTodayEditor();
  }

  Widget _buildTodayEditor() {
    final journalState = ref.watch(journalTodayControllerProvider);
    final promptState = ref.watch(journalPromptControllerProvider);
    final today = ref.watch(dateTimeServiceProvider).currentLocalDateString();

    return SafeArea(
      key: const ValueKey('journalPage'),
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
                onSaveDraft: (data) => _saveTodayEntry(data, complete: false),
                onComplete: (data) => _saveTodayEntry(data, complete: true),
                onReopen: entry == null ? null : _reopenTodayEntry,
                onApplyLatestPrompts: entry?.status == JournalEntryStatus.draft
                    ? _applyLatestPrompts
                    : null,
                onManagePrompts: () => context.push(RoutePaths.journalPrompts),
                onOpenHistory: () => context.push(RoutePaths.journalHistory),
                onDelete: entry == null
                    ? null
                    : () => _confirmDelete(entry, closeAfterDelete: false),
                onOpenDailyInsight: (recordDate, hasUnsavedChanges) =>
                    _openDailyInsight(
                      recordDate,
                      hasUnsavedChanges: hasUnsavedChanges,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoricalEditor(String targetDate) {
    final dateTimeService = ref.watch(dateTimeServiceProvider);
    final isValid = dateTimeService.isValidLocalDateString(targetDate);
    final targetState = isValid
        ? ref.watch(journalEntryForDateProvider(targetDate))
        : const AsyncData<JournalEntry?>(null);
    final visibleState = _historicalEntry?.entryDate == targetDate
        ? AsyncData<JournalEntry?>(_historicalEntry)
        : targetState;

    return SafeArea(
      key: const ValueKey('journalHistoricalEditorPage'),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('journalHistoricalEditorBackButton'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: '返回历史复盘',
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '编辑历史复盘',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: !isValid
                ? const _HistoricalJournalMessage(
                    message: '日期参数无效，无法定位 Journal 记录。',
                  )
                : visibleState.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        key: ValueKey('journalTargetLoadingState'),
                      ),
                    ),
                    error: (error, stackTrace) => _HistoricalJournalMessage(
                      message: '$targetDate 的 Journal 记录暂时无法读取。',
                      onRetry: () => ref.invalidate(
                        journalEntryForDateProvider(targetDate),
                      ),
                    ),
                    data: (entry) => entry == null
                        ? _HistoricalJournalMessage(
                            message: '未找到 $targetDate 的 Journal 记录。',
                          )
                        : ListView(
                            children: [
                              JournalForm(
                                title: targetDate,
                                entry: entry,
                                recordDate: entry.entryDate,
                                onSaveDraft: (data) =>
                                    _saveHistoricalEntry(entry, data),
                                onComplete: (data) =>
                                    _saveHistoricalEntry(entry, data),
                                onReopen:
                                    entry.status == JournalEntryStatus.completed
                                    ? () => _reopenHistoricalEntry(entry)
                                    : null,
                                onDelete: () => _confirmDelete(
                                  entry,
                                  closeAfterDelete: true,
                                ),
                                onOpenDailyInsight:
                                    (recordDate, hasUnsavedChanges) =>
                                        _openDailyInsight(
                                          recordDate,
                                          hasUnsavedChanges: hasUnsavedChanges,
                                        ),
                              ),
                            ],
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDailyInsight(
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
      if (!continueWithSaved || !mounted) return;
    }
    await context.push(RoutePaths.aiCoachDaily(recordDate));
  }

  Future<void> _saveTodayEntry(
    JournalSaveData data, {
    required bool complete,
  }) async {
    final controller = ref.read(journalTodayControllerProvider.notifier);
    if (complete) {
      await controller.completeReflection(data);
    } else {
      await controller.saveDraft(data);
    }
    ref.invalidate(journalControllerProvider);
  }

  Future<void> _reopenTodayEntry() async {
    await ref.read(journalTodayControllerProvider.notifier).reopen();
    ref.invalidate(journalControllerProvider);
  }

  Future<JournalEntry> _applyLatestPrompts() async {
    final saved = await ref
        .read(journalTodayControllerProvider.notifier)
        .applyLatestPrompts();
    ref.invalidate(journalControllerProvider);
    return saved;
  }

  Future<void> _saveHistoricalEntry(
    JournalEntry entry,
    JournalSaveData data,
  ) async {
    final saved = await ref
        .read(journalControllerProvider.notifier)
        .updateEntry(id: entry.id, data: data);
    if (!mounted) return;
    setState(() => _historicalEntry = saved);
  }

  Future<void> _reopenHistoricalEntry(JournalEntry entry) async {
    final saved = await ref
        .read(journalControllerProvider.notifier)
        .reopenEntry(entry.id);
    if (!mounted) return;
    setState(() => _historicalEntry = saved);
  }

  Future<void> _confirmDelete(
    JournalEntry entry, {
    required bool closeAfterDelete,
  }) async {
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
    if (!confirmed || !mounted) return;
    try {
      await ref.read(journalControllerProvider.notifier).deleteEntry(entry.id);
      await ref.read(journalTodayControllerProvider.notifier).reload();
      ref.invalidate(journalEntryForDateProvider(entry.entryDate));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Journal 已删除，等待手动同步')));
      if (closeAfterDelete) Navigator.of(context).maybePop();
    } on JournalConflictPendingException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('该 Journal 存在同步冲突，请先在设置的同步中心处理')),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('删除失败，本地记录未改变')));
    }
  }
}

class _HistoricalJournalMessage extends StatelessWidget {
  const _HistoricalJournalMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          key: const ValueKey('journalTargetNotice'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              IconButton(
                onPressed: onRetry,
                tooltip: '重新读取历史复盘',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
