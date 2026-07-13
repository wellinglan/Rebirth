import 'package:flutter/material.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_save_data.dart';

import 'duration_input_field.dart';

class TodayForm extends StatefulWidget {
  const TodayForm({
    required this.entry,
    required this.onSave,
    required this.onOpenHistory,
    super.key,
  });

  final TodayEntry entry;
  final Future<void> Function(TodaySaveData data) onSave;
  final VoidCallback onOpenHistory;

  @override
  State<TodayForm> createState() => _TodayFormState();
}

class _TodayFormState extends State<TodayForm> {
  static const _standardDurationQuickValues = <int>[15, 30, 45, 60, 90, 120];
  static const _sleepDurationQuickValues = <int>[360, 390, 420, 450, 480, 510];

  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _priorityControllers;
  late final TextEditingController _dailyNoteController;

  late List<bool> _priorityCompleted;
  int? _moodScore;
  int? _energyScore;
  int? _physicalStateScore;
  int? _researchMinutes;
  int? _learningMinutes;
  int? _sleepDurationMinutes;
  int? _exerciseDurationMinutes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _priorityControllers = List<TextEditingController>.generate(
      3,
      (_) => TextEditingController(),
    );
    _dailyNoteController = TextEditingController();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.entry.recordDate,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      TextButton.icon(
                        key: const ValueKey('openTodayHistoryButton'),
                        onPressed: widget.onOpenHistory,
                        icon: const Icon(Icons.history),
                        label: const Text('历史记录'),
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final mood = _ScoreField(
                        label: 'Mood',
                        value: _moodScore,
                        fieldKey: const ValueKey('moodScoreField'),
                        onChanged: (value) {
                          setState(() => _moodScore = value);
                        },
                      );
                      final energy = _ScoreField(
                        label: 'Energy',
                        value: _energyScore,
                        fieldKey: const ValueKey('energyScoreField'),
                        onChanged: (value) {
                          setState(() => _energyScore = value);
                        },
                      );

                      if (constraints.maxWidth < 560) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [mood, const SizedBox(height: 16), energy],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: mood),
                          const SizedBox(width: 20),
                          Expanded(child: energy),
                        ],
                      );
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
                            child: DurationInputField(
                              key: const ValueKey('researchMinutesField'),
                              label: '科研时间',
                              initialMinutes: widget.entry.researchMinutes,
                              quickValues: _standardDurationQuickValues,
                              onChanged: (value) {
                                setState(() => _researchMinutes = value);
                              },
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: DurationInputField(
                              key: const ValueKey('learningMinutesField'),
                              label: '学习时间',
                              initialMinutes: widget.entry.learningMinutes,
                              quickValues: _standardDurationQuickValues,
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
                  _SectionTitle(title: '健康摘要（可选）'),
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
                            child: DurationInputField(
                              key: const ValueKey('sleepMinutesField'),
                              label: '睡眠时长',
                              initialMinutes:
                                  widget.entry.health?.sleepDurationMinutes,
                              quickValues: _sleepDurationQuickValues,
                              onChanged: (value) {
                                setState(() => _sleepDurationMinutes = value);
                              },
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: DurationInputField(
                              key: const ValueKey('exerciseMinutesField'),
                              label: '运动时长',
                              initialMinutes:
                                  widget.entry.health?.exerciseDurationMinutes,
                              quickValues: _standardDurationQuickValues,
                              onChanged: (value) {
                                setState(
                                  () => _exerciseDurationMinutes = value,
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _ScoreField(
                    label: '身体状态',
                    value: _physicalStateScore,
                    fieldKey: const ValueKey('physicalStateScoreField'),
                    onChanged: (value) {
                      setState(() => _physicalStateScore = value);
                    },
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
      energyScore: _energyScore,
      researchMinutes: _researchMinutes,
      learningMinutes: _learningMinutes,
      dailyNote: _nullableText(_dailyNoteController.text),
      status: widget.entry.status,
      health: _buildHealthInput(),
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

  TodayHealthInput? _buildHealthInput() {
    final existing = widget.entry.health;

    if (existing == null &&
        _sleepDurationMinutes == null &&
        _exerciseDurationMinutes == null &&
        _physicalStateScore == null) {
      return null;
    }

    return TodayHealthInput(
      sleepDurationMinutes: _sleepDurationMinutes,
      weightKg: existing?.weightKg,
      waterIntakeMl: existing?.waterIntakeMl,
      exerciseType: existing?.exerciseType,
      exerciseDurationMinutes: _exerciseDurationMinutes,
      physicalStateScore: _physicalStateScore,
      note: existing?.note,
    );
  }

  void _syncFromEntry(TodayEntry entry) {
    for (var index = 0; index < 3; index++) {
      _priorityControllers[index].text = entry.priorities[index].text ?? '';
    }
    _priorityCompleted = entry.priorities
        .map((priority) => priority.completed)
        .toList(growable: false);
    _moodScore = entry.moodScore;
    _energyScore = entry.energyScore;
    _researchMinutes = entry.researchMinutes;
    _learningMinutes = entry.learningMinutes;
    _dailyNoteController.text = entry.dailyNote ?? '';
    _sleepDurationMinutes = entry.health?.sleepDurationMinutes;
    _exerciseDurationMinutes = entry.health?.exerciseDurationMinutes;
    _physicalStateScore = entry.health?.physicalStateScore;
  }

  bool get _hasAnyInput {
    return _priorityControllers.any(
          (controller) => controller.text.trim().isNotEmpty,
        ) ||
        _moodScore != null ||
        _energyScore != null ||
        _researchMinutes != null ||
        _learningMinutes != null ||
        _dailyNoteController.text.trim().isNotEmpty ||
        _sleepDurationMinutes != null ||
        _exerciseDurationMinutes != null ||
        _physicalStateScore != null;
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

class _ScoreField extends StatelessWidget {
  const _ScoreField({
    required this.label,
    required this.value,
    required this.fieldKey,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final Key fieldKey;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          key: fieldKey,
          segments: const <ButtonSegment<int>>[
            ButtonSegment(value: 1, label: Text('1')),
            ButtonSegment(value: 2, label: Text('2')),
            ButtonSegment(value: 3, label: Text('3')),
            ButtonSegment(value: 4, label: Text('4')),
            ButtonSegment(value: 5, label: Text('5')),
          ],
          selected: value == null ? const <int>{} : <int>{value!},
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            onChanged(selection.isEmpty ? null : selection.first);
          },
        ),
      ],
    );
  }
}
