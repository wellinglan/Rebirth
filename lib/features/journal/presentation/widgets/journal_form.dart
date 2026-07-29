import 'package:flutter/material.dart';
import 'package:rebirth/core/journal/journal_prompt_catalog.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/core/utils/deterministic_uuid.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_entry_prompt_item.dart';
import 'package:rebirth/features/journal/domain/journal_prompt.dart';
import 'package:rebirth/features/journal/domain/journal_save_data.dart';

import 'journal_question_field.dart';

class JournalForm extends StatefulWidget {
  const JournalForm({
    required this.entry,
    required this.recordDate,
    required this.onSaveDraft,
    required this.onComplete,
    this.prompts = const [],
    this.onApplyLatestPrompts,
    this.onManagePrompts,
    this.onReopen,
    this.onOpenDailyInsight,
    this.onDelete,
    super.key,
  });

  final JournalEntry? entry;
  final String recordDate;
  final List<JournalPromptDefinition> prompts;
  final Future<JournalEntry> Function()? onApplyLatestPrompts;
  final VoidCallback? onManagePrompts;
  final Future<void> Function(JournalSaveData data) onSaveDraft;
  final Future<void> Function(JournalSaveData data) onComplete;
  final Future<void> Function()? onReopen;
  final void Function(String recordDate, bool hasUnsavedChanges)?
  onOpenDailyInsight;
  final VoidCallback? onDelete;

  @override
  State<JournalForm> createState() => _JournalFormState();
}

class _JournalFormState extends State<JournalForm> {
  final Map<String, TextEditingController> _controllers = {};
  List<JournalEntryPromptItem> _items = const [];
  bool _isSaving = false;
  String? _contentError;

  bool get _isCompleted => widget.entry?.status == JournalEntryStatus.completed;

  @override
  void initState() {
    super.initState();
    _syncItems(force: true);
  }

  @override
  void didUpdateWidget(covariant JournalForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.entry, widget.entry) ||
        !identical(oldWidget.prompts, widget.prompts) ||
        oldWidget.recordDate != widget.recordDate) {
      _syncItems(force: !identical(oldWidget.entry, widget.entry));
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = widget.entry?.status;

    return PopScope(
      canPop: !_hasUnsavedChanges || _isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isSaving) _confirmDiscardChanges();
      },
      child: Padding(
        padding: AppLayout.pagePadding,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.maxContentWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text('今日复盘', style: theme.textTheme.titleLarge),
                    ),
                    if (widget.onManagePrompts != null)
                      IconButton(
                        key: const ValueKey('manageJournalPromptsButton'),
                        tooltip: '管理复盘问题',
                        onPressed: _isSaving ? null : widget.onManagePrompts,
                        icon: const Icon(Icons.tune),
                      ),
                    if (widget.entry?.status == JournalEntryStatus.draft &&
                        widget.onApplyLatestPrompts != null)
                      IconButton(
                        key: const ValueKey('applyLatestJournalPromptsButton'),
                        tooltip: '应用最新问题',
                        onPressed: _isSaving ? null : _confirmApplyLatest,
                        icon: const Icon(Icons.refresh),
                      ),
                    if (widget.onOpenDailyInsight != null)
                      IconButton(
                        key: const ValueKey(
                          'openDailyInsightFromJournalButton',
                        ),
                        tooltip: '生成该日洞察（仅读取已保存记录）',
                        onPressed: () => widget.onOpenDailyInsight!(
                          widget.recordDate,
                          _hasUnsavedChanges,
                        ),
                        icon: const Icon(Icons.auto_awesome_outlined),
                      ),
                    if (widget.entry != null && widget.onDelete != null)
                      IconButton(
                        key: const ValueKey('deleteJournalButton'),
                        tooltip: '删除该 Journal',
                        onPressed: _isSaving ? null : widget.onDelete,
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.entry?.entryDate ?? '写下今天值得理解的部分',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (status != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Semantics(
                    label: '记录状态：${status.displayLabel}',
                    container: true,
                    child: Text(
                      '记录状态：${status.displayLabel}',
                      key: const ValueKey('journalStatusLabel'),
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                for (var index = 0; index < _items.length; index++) ...[
                  JournalQuestionField(
                    question: _items[index].questionTextSnapshot,
                    helperText: _items[index].helperTextSnapshot,
                    controller: _controllers[_items[index].id]!,
                    fieldKey: _fieldKeyFor(_items[index]),
                    onChanged: _handleChanged,
                    readOnly: _isCompleted,
                  ),
                  if (index != _items.length - 1) const SizedBox(height: 16),
                ],
                if (_contentError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _contentError!,
                    key: const ValueKey('journalContentError'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: _isCompleted
                      ? OutlinedButton.icon(
                          key: const ValueKey('reopenJournalButton'),
                          onPressed: _isSaving || widget.onReopen == null
                              ? null
                              : _confirmReopen,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('重新编辑'),
                        )
                      : Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          alignment: WrapAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              key: const ValueKey('saveJournalButton'),
                              onPressed: _isSaving
                                  ? null
                                  : () => _submit(
                                      status: JournalEntryStatus.draft,
                                      operation: widget.onSaveDraft,
                                    ),
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('保存草稿'),
                            ),
                            FilledButton.icon(
                              key: const ValueKey('completeJournalButton'),
                              onPressed: _isSaving
                                  ? null
                                  : () => _submit(
                                      status: JournalEntryStatus.completed,
                                      operation: widget.onComplete,
                                    ),
                              icon: _isSaving
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        key: ValueKey(
                                          'journalSaveProgressIndicator',
                                        ),
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle_outline),
                              label: Text(_isSaving ? '处理中...' : '完成复盘'),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit({
    required JournalEntryStatus status,
    required Future<void> Function(JournalSaveData data) operation,
  }) async {
    if (_isSaving) return;
    final data = _buildData(status);
    if (data == null) return;

    setState(() {
      _contentError = null;
      _isSaving = true;
    });
    try {
      await operation(data);
      if (!mounted) return;
      final message = status == JournalEntryStatus.completed
          ? '今日复盘已完成'
          : '复盘草稿已保存';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('操作失败，内容已保留，请重试')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmReopen() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            key: const ValueKey('confirmReopenJournalDialog'),
            title: const Text('重新编辑这篇复盘？'),
            content: const Text('确认后记录会变为草稿，已有内容不会丢失。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                key: const ValueKey('confirmReopenJournalButton'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('重新编辑'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await widget.onReopen!();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('记录已重新变为草稿')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('重新编辑失败，请稍后重试')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmApplyLatest() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            key: const ValueKey('confirmApplyLatestJournalPromptsDialog'),
            title: const Text('应用最新问题？'),
            content: const Text('会保留仍能匹配的问题答案，并按当前配置更新这篇草稿的问题集合。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                key: const ValueKey('confirmApplyLatestJournalPromptsButton'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('应用'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final entry = await widget.onApplyLatestPrompts!();
      if (!mounted) return;
      _replaceItems(entry.promptItems);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('已应用最新问题')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('更新问题失败，原内容已保留')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDiscardChanges() async {
    final discard =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            key: const ValueKey('journalUnsavedChangesDialog'),
            title: const Text('放弃未保存修改？'),
            content: const Text('离开后，这次尚未保存的复盘内容会丢失。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('继续编辑'),
              ),
              FilledButton(
                key: const ValueKey('discardJournalChangesButton'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('放弃修改'),
              ),
            ],
          ),
        ) ??
        false;
    if (discard && mounted) Navigator.of(context).pop();
  }

  JournalSaveData? _buildData(JournalEntryStatus status) {
    final items = [
      for (final item in _items)
        item.copyWith(
          answerText: _nullableText(_controllers[item.id]!.text),
          clearAnswer: _nullableText(_controllers[item.id]!.text) == null,
        ),
    ];
    if (!items.any((item) => item.hasAnswer)) {
      setState(() => _contentError = '至少填写一项复盘内容');
      return null;
    }
    String? answerFor(String stableKey) {
      for (final item in items) {
        if (item.sourcePromptStableKey == stableKey) return item.answerText;
      }
      return null;
    }

    return JournalSaveData(
      mostImportantAccomplishment: answerFor(
        JournalPromptCatalog.accomplishmentKey,
      ),
      mostDrainingEvent: answerFor(JournalPromptCatalog.drainingEventKey),
      emotionSource: answerFor(JournalPromptCatalog.emotionSourceKey),
      learning: answerFor(JournalPromptCatalog.learningKey),
      tomorrowAdjustment: answerFor(JournalPromptCatalog.tomorrowAdjustmentKey),
      promptItems: items,
      status: status,
    );
  }

  void _handleChanged(String value) {
    if (_contentError != null) setState(() => _contentError = null);
  }

  void _syncItems({required bool force}) {
    final next = widget.entry?.promptItems ?? _itemsFromPrompts();
    if (!force && _itemsHaveSameIdentity(_items, next)) return;
    _replaceItems(next);
  }

  void _replaceItems(List<JournalEntryPromptItem> next) {
    final nextIds = next.map((item) => item.id).toSet();
    final removedIds = _controllers.keys
        .where((id) => !nextIds.contains(id))
        .toList(growable: false);
    for (final id in removedIds) {
      _controllers.remove(id)?.dispose();
    }
    for (final item in next) {
      final controller = _controllers.putIfAbsent(
        item.id,
        () => TextEditingController(),
      );
      controller.text = item.answerText ?? '';
    }
    _items = List.unmodifiable(
      List<JournalEntryPromptItem>.of(next)..sort((left, right) {
        final order = left.displayOrder.compareTo(right.displayOrder);
        return order != 0 ? order : left.id.compareTo(right.id);
      }),
    );
  }

  List<JournalEntryPromptItem> _itemsFromPrompts() {
    final prompts = widget.prompts.isEmpty
        ? [
            for (final prompt in JournalPromptCatalog.prompts)
              JournalPromptDefinition(
                id: deterministicUuid('system-prompt:${prompt.stableKey}'),
                configurationId: 'default',
                stableKey: prompt.stableKey,
                source: JournalPromptSource.system,
                questionText: prompt.questionText,
                helperText: prompt.helperText,
                responseKind: JournalResponseKind.longText,
                displayOrder: prompt.displayOrder,
                isEnabled: true,
                promptVersion: 1,
                createdAt: 0,
                updatedAt: 0,
                deletedAt: null,
              ),
          ]
        : widget.prompts;
    return [
      for (final prompt in prompts.where(
        (prompt) => prompt.isEnabled && !prompt.isDeleted,
      ))
        JournalEntryPromptItem(
          id: deterministicUuid(
            'journal-draft:${widget.recordDate}:${prompt.id}:${prompt.promptVersion}',
          ),
          sourcePromptId: prompt.id,
          sourcePromptStableKey: prompt.stableKey,
          sourcePromptVersion: prompt.promptVersion,
          promptSource: prompt.source,
          questionTextSnapshot: prompt.questionText,
          helperTextSnapshot: prompt.helperText,
          responseKind: prompt.responseKind,
          displayOrder: prompt.displayOrder,
          answerText: null,
          createdAt: 0,
          updatedAt: 0,
        ),
    ];
  }

  bool get _hasUnsavedChanges {
    final saved = {
      for (final item in widget.entry?.promptItems ?? const [])
        item.id: _nullableText(item.answerText ?? ''),
    };
    for (final item in _items) {
      if (_nullableText(_controllers[item.id]!.text) != saved[item.id]) {
        return true;
      }
    }
    return saved.keys.any((id) => !_items.any((item) => item.id == id));
  }

  bool _itemsHaveSameIdentity(
    List<JournalEntryPromptItem> left,
    List<JournalEntryPromptItem> right,
  ) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index].id != right[index].id) return false;
    }
    return true;
  }

  Key _fieldKeyFor(JournalEntryPromptItem item) {
    return switch (item.sourcePromptStableKey) {
      JournalPromptCatalog.accomplishmentKey => const ValueKey(
        'journalAccomplishmentField',
      ),
      JournalPromptCatalog.drainingEventKey => const ValueKey(
        'journalDrainingField',
      ),
      JournalPromptCatalog.emotionSourceKey => const ValueKey(
        'journalEmotionField',
      ),
      JournalPromptCatalog.learningKey => const ValueKey(
        'journalLearningField',
      ),
      JournalPromptCatalog.tomorrowAdjustmentKey => const ValueKey(
        'journalAdjustmentField',
      ),
      _ => ValueKey('journalPromptField_${item.id}'),
    };
  }

  String? _nullableText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
