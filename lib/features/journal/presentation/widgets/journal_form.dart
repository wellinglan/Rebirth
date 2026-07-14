import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_save_data.dart';

import 'journal_question_field.dart';

class JournalForm extends StatefulWidget {
  const JournalForm({required this.entry, required this.onSave, super.key});

  final JournalEntry? entry;
  final Future<void> Function(JournalSaveData data) onSave;

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
              Text('今日复盘', style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                widget.entry?.entryDate ?? '写下今天值得理解的部分',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              JournalQuestionField(
                question: '今天最重要的完成是什么？',
                controller: _accomplishmentController,
                fieldKey: const ValueKey('journalAccomplishmentField'),
                onChanged: _handleChanged,
              ),
              const SizedBox(height: 16),
              JournalQuestionField(
                question: '今天最消耗我的事情是什么？',
                controller: _drainingController,
                fieldKey: const ValueKey('journalDrainingField'),
                onChanged: _handleChanged,
              ),
              const SizedBox(height: 16),
              JournalQuestionField(
                question: '今天主要情绪的来源是什么？',
                controller: _emotionController,
                fieldKey: const ValueKey('journalEmotionField'),
                onChanged: _handleChanged,
              ),
              const SizedBox(height: 16),
              JournalQuestionField(
                question: '今天我学到了什么？',
                controller: _learningController,
                fieldKey: const ValueKey('journalLearningField'),
                onChanged: _handleChanged,
              ),
              const SizedBox(height: 16),
              JournalQuestionField(
                question: '明天我想如何调整？',
                controller: _adjustmentController,
                fieldKey: const ValueKey('journalAdjustmentField'),
                onChanged: _handleChanged,
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
                child: FilledButton.icon(
                  key: const ValueKey('saveJournalButton'),
                  onPressed: _isSaving ? null : _submit,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            key: ValueKey('journalSaveProgressIndicator'),
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? '保存中...' : '保存复盘'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }

    final values = _controllers
        .map((controller) => _nullableText(controller.text))
        .toList(growable: false);
    if (values.every((value) => value == null)) {
      setState(() => _contentError = '至少填写一项复盘内容');
      return;
    }

    final data = JournalSaveData(
      mostImportantAccomplishment: values[0],
      mostDrainingEvent: values[1],
      emotionSource: values[2],
      learning: values[3],
      tomorrowAdjustment: values[4],
      status: widget.entry?.status ?? JournalEntryStatus.draft,
    );

    setState(() {
      _contentError = null;
      _isSaving = true;
    });
    try {
      await widget.onSave(data);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('今日复盘已保存')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _handleChanged(String value) {
    if (_contentError != null) {
      setState(() => _contentError = null);
    }
  }

  void _syncFromEntry(JournalEntry? entry) {
    _accomplishmentController.text = entry?.mostImportantAccomplishment ?? '';
    _drainingController.text = entry?.mostDrainingEvent ?? '';
    _emotionController.text = entry?.emotionSource ?? '';
    _learningController.text = entry?.learning ?? '';
    _adjustmentController.text = entry?.tomorrowAdjustment ?? '';
  }

  String? _nullableText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
