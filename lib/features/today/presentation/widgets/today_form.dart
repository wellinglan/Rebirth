import 'package:flutter/material.dart';
import 'package:rebirth/core/theme/app_layout.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_save_data.dart';
import 'package:rebirth/core/theme/app_typography.dart';
import 'package:rebirth/shared/widgets/duration_step_input.dart';
import 'package:rebirth/shared/widgets/wellbeing_rating_field.dart';

class TodayForm extends StatefulWidget {
  const TodayForm({
    required this.entry,
    required this.onSave,
    required this.onOpenHistory,
    this.onDelete,
    this.onOpenDailyInsight,
    super.key,
  });

  final TodayEntry entry;
  final Future<void> Function(TodaySaveData data) onSave;
  final VoidCallback onOpenHistory;
  final VoidCallback? onDelete;
  final VoidCallback? onOpenDailyInsight;

  @override
  State<TodayForm> createState() => _TodayFormState();
}

class _TodayFormState extends State<TodayForm> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _priorityControllers;
  late final TextEditingController _dailyNoteController;
  late final TextEditingController _moodDescriptionController;
  late final TextEditingController _energyDescriptionController;

  late List<bool> _priorityCompleted;
  int? _moodScore;
  int? _energyScore;
  int? _researchMinutes;
  int? _learningMinutes;
  int _researchStep = 15;
  int _learningStep = 15;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _priorityControllers = List<TextEditingController>.generate(
      3,
      (_) => TextEditingController(),
    );
    _dailyNoteController = TextEditingController();
    _moodDescriptionController = TextEditingController();
    _energyDescriptionController = TextEditingController();
    _syncFromEntry(widget.entry);
  }

  @override
  void didUpdateWidget(covariant TodayForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.entry, widget.entry)) {
      _syncFromEntry(widget.entry);
    }
  }

  @override
  void dispose() {
    for (final controller in _priorityControllers) {
      controller.dispose();
    }
    _dailyNoteController.dispose();
    _moodDescriptionController.dispose();
    _energyDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: ListView(
        padding: AppLayout.pagePadding,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.maxContentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.entry.recordDate,
                    style: AppTypography.numericStyle(
                      theme.textTheme.titleLarge!,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (widget.onOpenDailyInsight != null)
                        TextButton.icon(
                          key: const ValueKey(
                            'openDailyInsightFromTodayButton',
                          ),
                          onPressed: widget.onOpenDailyInsight,
                          icon: const Icon(Icons.auto_awesome_outlined),
                          label: const Text('生成今日洞察'),
                        ),
                      TextButton.icon(
                        key: const ValueKey('openTodayHistoryButton'),
                        onPressed: widget.onOpenHistory,
                        icon: const Icon(Icons.history),
                        label: const Text('历史记录'),
                      ),
                      if (widget.onDelete != null)
                        TextButton.icon(
                          key: const ValueKey('deleteTodayButton'),
                          onPressed: widget.onDelete,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('删除记录'),
                        ),
                    ],
                  ),
                  if (!_hasAnyInput) ...[
                    const SizedBox(height: 6),
                    Text(
                      '今天还没有填写内容',
                      key: const ValueKey('todayEmptyState'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _SectionTitle(title: '今日三件事'),
                  const SizedBox(height: 10),
                  for (var index = 0; index < 3; index++) ...[
                    _buildPriorityField(index),
                    if (index < 2) const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 28),
                  _SectionTitle(title: '今日状态'),
                  const SizedBox(height: 10),
                  WellbeingRatingField(
                    key: const ValueKey('moodScoreField'),
                    label: '心情',
                    icon: Icons.sentiment_satisfied_alt_outlined,
                    value: _moodScore,
                    description: _moodDescriptionController.text,
                    descriptionHint: '一句话记下今天的心情',
                    onScoreChanged: (value) =>
                        setState(() => _moodScore = value),
                    onDescriptionChanged: (value) {
                      _moodDescriptionController.text = value;
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  WellbeingRatingField(
                    key: const ValueKey('energyScoreField'),
                    label: '精力',
                    icon: Icons.bolt_outlined,
                    value: _energyScore,
                    description: _energyDescriptionController.text,
                    descriptionHint: '一句话记下精力状态',
                    onScoreChanged: (value) =>
                        setState(() => _energyScore = value),
                    onDescriptionChanged: (value) {
                      _energyDescriptionController.text = value;
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 28),
                  _SectionTitle(title: '时间投入'),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final fieldWidth = constraints.maxWidth < 480
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 12) / 2;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: fieldWidth,
                            child: DurationStepInput(
                              key: const ValueKey('researchMinutesField'),
                              label: '科研时间',
                              icon: Icons.science_outlined,
                              value: _researchMinutes,
                              selectedStep: _researchStep,
                              onStepChanged: (value) =>
                                  setState(() => _researchStep = value),
                              onChanged: (value) {
                                setState(() => _researchMinutes = value);
                              },
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: DurationStepInput(
                              key: const ValueKey('learningMinutesField'),
                              label: '学习时间',
                              icon: Icons.menu_book_outlined,
                              value: _learningMinutes,
                              selectedStep: _learningStep,
                              onStepChanged: (value) =>
                                  setState(() => _learningStep = value),
                              onChanged: (value) {
                                setState(() => _learningMinutes = value);
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  _SectionTitle(title: '今日一句话'),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('dailyNoteField'),
                    controller: _dailyNoteController,
                    minLines: 2,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: '记下今天最想保留的一句话',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 28),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      key: const ValueKey('saveTodayButton'),
                      onPressed: _isSaving ? null : _submit,
                      icon: _isSaving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                key: ValueKey('saveProgressIndicator'),
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_isSaving ? '保存中...' : '保存'),
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

  Widget _buildPriorityField(int index) {
    final hasText = _priorityControllers[index].text.trim().isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Checkbox(
            key: ValueKey('priority${index + 1}Completed'),
            value: hasText && _priorityCompleted[index],
            onChanged: hasText
                ? (value) {
                    setState(() => _priorityCompleted[index] = value ?? false);
                  }
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            key: ValueKey('priority${index + 1}Field'),
            controller: _priorityControllers[index],
            textInputAction: index == 2
                ? TextInputAction.done
                : TextInputAction.next,
            decoration: InputDecoration(
              labelText: '第 ${index + 1} 件事',
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                if (value.trim().isEmpty) {
                  _priorityCompleted[index] = false;
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final priorities = List<TodayPriority>.generate(3, (index) {
      return TodayPriority(
        text: _nullableText(_priorityControllers[index].text),
        completed: _priorityCompleted[index],
        goalId: widget.entry.priorities[index].goalId,
      );
    }, growable: false);

    final data = TodaySaveData(
      priorities: priorities,
      moodScore: _moodScore,
      moodDescription: _nullableText(_moodDescriptionController.text),
      energyScore: _energyScore,
      energyDescription: _nullableText(_energyDescriptionController.text),
      researchMinutes: _researchMinutes,
      learningMinutes: _learningMinutes,
      dailyNote: _nullableText(_dailyNoteController.text),
      status: widget.entry.status,
    );

    setState(() => _isSaving = true);
    try {
      await widget.onSave(data);
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

  void _syncFromEntry(TodayEntry entry) {
    for (var index = 0; index < 3; index++) {
      _priorityControllers[index].text = entry.priorities[index].text ?? '';
    }
    _priorityCompleted = entry.priorities
        .map((priority) => priority.completed)
        .toList(growable: false);
    _moodScore = entry.moodScore;
    _moodDescriptionController.text = entry.moodDescription ?? '';
    _energyScore = entry.energyScore;
    _energyDescriptionController.text = entry.energyDescription ?? '';
    _researchMinutes = entry.researchMinutes;
    _learningMinutes = entry.learningMinutes;
    _dailyNoteController.text = entry.dailyNote ?? '';
  }

  bool get _hasAnyInput {
    return _priorityControllers.any(
          (controller) => controller.text.trim().isNotEmpty,
        ) ||
        _moodScore != null ||
        _moodDescriptionController.text.trim().isNotEmpty ||
        _energyScore != null ||
        _energyDescriptionController.text.trim().isNotEmpty ||
        _researchMinutes != null ||
        _learningMinutes != null ||
        _dailyNoteController.text.trim().isNotEmpty;
  }

  String? _nullableText(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}
