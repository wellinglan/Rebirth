import 'package:flutter/material.dart';
import 'package:rebirth/features/health/domain/health_entry.dart';
import 'package:rebirth/features/health/domain/health_save_data.dart';
import 'package:rebirth/shared/widgets/duration_input_field.dart';

class HealthForm extends StatefulWidget {
  const HealthForm({
    required this.entry,
    required this.isSaving,
    required this.onSave,
    super.key,
  });

  final HealthEntry entry;
  final bool isSaving;
  final Future<void> Function(HealthSaveData data) onSave;

  @override
  State<HealthForm> createState() => _HealthFormState();
}

class _HealthFormState extends State<HealthForm> {
  static const _sleepQuickValues = <int>[360, 390, 420, 450, 480, 510];
  static const _exerciseQuickValues = <int>[15, 30, 45, 60, 90, 120];
  static const _waterQuickValues = <int>[500, 1000, 1500, 2000, 2500];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weightController;
  late final TextEditingController _waterController;
  late final TextEditingController _exerciseTypeController;
  late final TextEditingController _noteController;
  int? _sleepDurationMinutes;
  int? _exerciseDurationMinutes;
  int? _physicalStateScore;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController();
    _waterController = TextEditingController();
    _exerciseTypeController = TextEditingController();
    _noteController = TextEditingController();
    _syncFromEntry(widget.entry);
  }

  @override
  void didUpdateWidget(covariant HealthForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id ||
        oldWidget.entry.updatedAt != widget.entry.updatedAt) {
      _syncFromEntry(widget.entry);
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _waterController.dispose();
    _exerciseTypeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('今日健康记录', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(widget.entry.recordDate),
          const SizedBox(height: 20),
          DurationInputField(
            key: const ValueKey('healthSleepDurationField'),
            label: '睡眠时长',
            initialMinutes: widget.entry.sleepDurationMinutes,
            quickValues: _sleepQuickValues,
            onChanged: (value) => _sleepDurationMinutes = value,
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const ValueKey('healthWeightField'),
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '体重（kg）',
              border: OutlineInputBorder(),
            ),
            validator: _validateWeight,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('healthWaterField'),
            controller: _waterController,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            decoration: const InputDecoration(
              labelText: '饮水（ml）',
              border: OutlineInputBorder(),
            ),
            validator: _validateWater,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final value in _waterQuickValues)
                ActionChip(
                  label: Text('$value ml'),
                  onPressed: () => _waterController.text = '$value',
                ),
            ],
          ),
          const SizedBox(height: 20),
          DurationInputField(
            key: const ValueKey('healthExerciseDurationField'),
            label: '运动时长',
            initialMinutes: widget.entry.exerciseDurationMinutes,
            quickValues: _exerciseQuickValues,
            onChanged: (value) => _exerciseDurationMinutes = value,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('healthExerciseTypeField'),
            controller: _exerciseTypeController,
            decoration: const InputDecoration(
              labelText: '运动类型（可选）',
              hintText: '跑步、力量、散步、骑行',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            key: const ValueKey('healthPhysicalStateField'),
            initialValue: _physicalStateScore,
            decoration: const InputDecoration(
              labelText: '身体状态（可选）',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem<int?>(value: null, child: Text('未填写')),
              DropdownMenuItem<int?>(value: 1, child: Text('1 · 很疲惫')),
              DropdownMenuItem<int?>(value: 2, child: Text('2 · 偏疲惫')),
              DropdownMenuItem<int?>(value: 3, child: Text('3 · 正常')),
              DropdownMenuItem<int?>(value: 4, child: Text('4 · 状态好')),
              DropdownMenuItem<int?>(value: 5, child: Text('5 · 精神很好')),
            ],
            onChanged: (value) => setState(() => _physicalStateScore = value),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('healthNoteField'),
            controller: _noteController,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '备注（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const ValueKey('saveHealthButton'),
              onPressed: widget.isSaving || _isSubmitting ? null : _submit,
              icon: widget.isSaving || _isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                widget.isSaving || _isSubmitting ? '保存中...' : '保存健康记录',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final data = HealthSaveData(
      recordDate: widget.entry.recordDate,
      sleepDurationMinutes: _sleepDurationMinutes,
      weightKg: _parseDouble(_weightController.text),
      waterIntakeMl: _parseInt(_waterController.text),
      exerciseDurationMinutes: _exerciseDurationMinutes,
      exerciseType: _exerciseTypeController.text,
      physicalStateScore: _physicalStateScore,
      note: _noteController.text,
    );

    setState(() => _isSubmitting = true);
    try {
      await widget.onSave(data);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('健康记录已保存')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String? _validateWeight(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final weight = double.tryParse(text);
    if (weight == null || weight <= 0) {
      return '请输入大于 0 的数字';
    }
    return null;
  }

  String? _validateWater(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final water = int.tryParse(text);
    if (water == null || water < 0) {
      return '请输入非负整数';
    }
    return null;
  }

  int? _parseInt(String value) {
    final text = value.trim();
    return text.isEmpty ? null : int.parse(text);
  }

  double? _parseDouble(String value) {
    final text = value.trim();
    return text.isEmpty ? null : double.parse(text);
  }

  void _syncFromEntry(HealthEntry entry) {
    _sleepDurationMinutes = entry.sleepDurationMinutes;
    _exerciseDurationMinutes = entry.exerciseDurationMinutes;
    _weightController.text = entry.weightKg?.toString() ?? '';
    _waterController.text = entry.waterIntakeMl?.toString() ?? '';
    _exerciseTypeController.text = entry.exerciseType ?? '';
    _physicalStateScore = entry.physicalStateScore;
    _noteController.text = entry.note ?? '';
  }
}
