import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_save_data.dart';

import 'journal_question_field.dart';

class JournalForm extends StatefulWidget {
  const JournalForm({
    required this.entry,
    required this.recordDate,
    required this.onSaveDraft,
    required this.onComplete,
    this.onReopen,
    this.onOpenDailyInsight,
    this.onDelete,
    super.key,
  });

  final JournalEntry? entry;
  final String recordDate;
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
  late final TextEditingController _accomplishmentController;
  late final TextEditingController _drainingController;
  late final TextEditingController _emotionController;
  late final TextEditingController _learningController;
  late final TextEditingController _adjustmentController;

  bool _isSaving = false;
  String? _contentError;

  bool get _isCompleted => widget.entry?.status == JournalEntryStatus.completed;

  List<TextEditingController> get _controllers => [
    _accomplishmentController,
    _drainingController,
    _emotionController,
    _learningController,
    _adjustmentController,
  ];

  @override
  void initState() {
    super.initState();
    _accomplishmentController = TextEditingController();
    _drainingController = TextEditingController();
    _emotionController = TextEditingController();
    _learningController = TextEditingController();
    _adjustmentController = TextEditingController();
    _syncFromEntry(widget.entry);
  }

  @override
  void didUpdateWidget(covariant JournalForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.entry, widget.entry)) {
      _syncFromEntry(widget.entry);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = widget.entry?.status;

    return Padding(
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
                  if (widget.onOpenDailyInsight != null)
                    IconButton(
                      key: const ValueKey('openDailyInsightFromJournalButton'),
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
              const SizedBox(height: 24),
              JournalQuestionField(
                question: '今天最重要的完成是什么？',
                controller: _accomplishmentController,
                fieldKey: const ValueKey('journalAccomplishmentField'),
                onChanged: _handleChanged,
                readOnly: _isCompleted,
              ),
              const SizedBox(height: 16),
              JournalQuestionField(
                question: '今天最消耗我的事情是什么？',
                controller: _drainingController,
                fieldKey: const ValueKey('journalDrainingField'),
                onChanged: _handleChanged,
                readOnly: _isCompleted,
              ),
              const SizedBox(height: 16),
              JournalQuestionField(
                question: '今天主要情绪的来源是什么？',
                controller: _emotionController,
                fieldKey: const ValueKey('journalEmotionField'),
                onChanged: _handleChanged,
                readOnly: _isCompleted,
              ),
              const SizedBox(height: 16),
              JournalQuestionField(
                question: '今天我学到了什么？',
                controller: _learningController,
                fieldKey: const ValueKey('journalLearningField'),
                onChanged: _handleChanged,
                readOnly: _isCompleted,
              ),
              const SizedBox(height: 16),
              JournalQuestionField(
                question: '明天我想如何调整？',
                controller: _adjustmentController,
                fieldKey: const ValueKey('journalAdjustmentField'),
                onChanged: _handleChanged,
                readOnly: _isCompleted,
              ),
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

  JournalSaveData? _buildData(JournalEntryStatus status) {
    final values = _controllers
        .map((controller) => _nullableText(controller.text))
        .toList(growable: false);
    if (values.every((value) => value == null)) {
      setState(() => _contentError = '至少填写一项复盘内容');
      return null;
    }
    return JournalSaveData(
      mostImportantAccomplishment: values[0],
      mostDrainingEvent: values[1],
      emotionSource: values[2],
      learning: values[3],
      tomorrowAdjustment: values[4],
      status: status,
    );
  }

  void _handleChanged(String value) {
    if (_contentError != null) setState(() => _contentError = null);
  }

  void _syncFromEntry(JournalEntry? entry) {
    _accomplishmentController.text = entry?.mostImportantAccomplishment ?? '';
    _drainingController.text = entry?.mostDrainingEvent ?? '';
    _emotionController.text = entry?.emotionSource ?? '';
    _learningController.text = entry?.learning ?? '';
    _adjustmentController.text = entry?.tomorrowAdjustment ?? '';
  }

  bool get _hasUnsavedChanges {
    final saved = <String?>[
      widget.entry?.mostImportantAccomplishment,
      widget.entry?.mostDrainingEvent,
      widget.entry?.emotionSource,
      widget.entry?.learning,
      widget.entry?.tomorrowAdjustment,
    ];
    final current = _controllers
        .map((controller) => _nullableText(controller.text))
        .toList(growable: false);
    for (var index = 0; index < current.length; index++) {
      if (current[index] != saved[index]) return true;
    }
    return false;
  }

  String? _nullableText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
