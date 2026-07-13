import 'package:flutter/material.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_save_data.dart';

class TodayForm extends StatefulWidget {
  const TodayForm({required this.entry, required this.onSave, super.key});

  final TodayEntry entry;
  final Future<void> Function(TodaySaveData data) onSave;

  @override
  State<TodayForm> createState() => _TodayFormState();
}

class _TodayFormState extends State<TodayForm> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _priorityControllers;
  late final TextEditingController _researchController;
  late final TextEditingController _learningController;
  late final TextEditingController _dailyNoteController;
  late final TextEditingController _sleepController;
  late final TextEditingController _exerciseController;

  late List<bool> _priorityCompleted;
  int? _moodScore;
  int? _energyScore;
  int? _physicalStateScore;

  @override
  void initState() {
    super.initState();
    _priorityControllers = List<TextEditingController>.generate(
      3,
      (_) => TextEditingController(),
    );
    _researchController = TextEditingController();
    _learningController = TextEditingController();
    _dailyNoteController = TextEditingController();
    _sleepController = TextEditingController();
    _exerciseController = TextEditingController();
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
    _researchController.dispose();
    _learningController.dispose();
    _dailyNoteController.dispose();
    _sleepController.dispose();
    _exerciseController.dispose();
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
                  Text(
                    widget.entry.recordDate,
                    style: theme.textTheme.titleLarge,
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
                            child: _buildMinutesField(
                              key: const ValueKey('researchMinutesField'),
                              controller: _researchController,
                              label: '科研时间',
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _buildMinutesField(
                              key: const ValueKey('learningMinutesField'),
                              controller: _learningController,
                              label: '学习时间',
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
                            child: _buildMinutesField(
                              key: const ValueKey('sleepMinutesField'),
                              controller: _sleepController,
                              label: '睡眠时长',
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _buildMinutesField(
                              key: const ValueKey('exerciseMinutesField'),
                              controller: _exerciseController,
                              label: '运动时长',
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
                      onPressed: _submit,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('保存'),
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

  Widget _buildMinutesField({
    required Key key,
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        suffixText: '分钟',
        border: const OutlineInputBorder(),
      ),
      validator: _validateMinutes,
      onChanged: (_) => setState(() {}),
    );
  }

  String? _validateMinutes(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }

    final minutes = int.tryParse(text);
    if (minutes == null || minutes < 0) {
      return '请输入非负整数';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final priorities = List<TodayPriority>.generate(3, (index) {
      return TodayPriority(
        text: _nullableText(_priorityControllers[index].text),
        completed: _priorityCompleted[index],
        goalId: widget.entry.priorities[index].goalId,
      );
    }, growable: false);

    await widget.onSave(
      TodaySaveData(
        priorities: priorities,
        moodScore: _moodScore,
        energyScore: _energyScore,
        researchMinutes: _nullableMinutes(_researchController.text),
        learningMinutes: _nullableMinutes(_learningController.text),
        dailyNote: _nullableText(_dailyNoteController.text),
        status: widget.entry.status,
        health: _buildHealthInput(),
      ),
    );
  }

  TodayHealthInput? _buildHealthInput() {
    final sleep = _nullableMinutes(_sleepController.text);
    final exercise = _nullableMinutes(_exerciseController.text);
    final existing = widget.entry.health;

    if (existing == null &&
        sleep == null &&
        exercise == null &&
        _physicalStateScore == null) {
      return null;
    }

    return TodayHealthInput(
      sleepDurationMinutes: sleep,
      weightKg: existing?.weightKg,
      waterIntakeMl: existing?.waterIntakeMl,
      exerciseType: existing?.exerciseType,
      exerciseDurationMinutes: exercise,
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
    _researchController.text = _minutesText(entry.researchMinutes);
    _learningController.text = _minutesText(entry.learningMinutes);
    _dailyNoteController.text = entry.dailyNote ?? '';
    _sleepController.text = _minutesText(entry.health?.sleepDurationMinutes);
    _exerciseController.text = _minutesText(
      entry.health?.exerciseDurationMinutes,
    );
    _physicalStateScore = entry.health?.physicalStateScore;
  }

  bool get _hasAnyInput {
    return _priorityControllers.any(
          (controller) => controller.text.trim().isNotEmpty,
        ) ||
        _moodScore != null ||
        _energyScore != null ||
        _researchController.text.trim().isNotEmpty ||
        _learningController.text.trim().isNotEmpty ||
        _dailyNoteController.text.trim().isNotEmpty ||
        _sleepController.text.trim().isNotEmpty ||
        _exerciseController.text.trim().isNotEmpty ||
        _physicalStateScore != null;
  }

  String _minutesText(int? value) => value?.toString() ?? '';

  int? _nullableMinutes(String value) {
    final text = value.trim();
    return text.isEmpty ? null : int.parse(text);
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
