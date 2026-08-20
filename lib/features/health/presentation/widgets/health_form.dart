import 'package:flutter/material.dart';
import 'package:rebirth/features/health/domain/health_entry.dart';
import 'package:rebirth/features/health/domain/health_save_data.dart';
import 'package:rebirth/shared/widgets/duration_step_input.dart';
import 'package:rebirth/shared/widgets/quick_increment_control.dart';
import 'package:rebirth/shared/widgets/water_cup_indicator.dart';
import 'package:rebirth/shared/widgets/wellbeing_rating_field.dart';

class HealthForm extends StatefulWidget {
  const HealthForm({
    required this.entry,
    required this.isSaving,
    required this.onSave,
    this.onDelete,
    super.key,
  });

  final HealthEntry entry;
  final bool isSaving;
  final Future<void> Function(HealthSaveData data) onSave;
  final VoidCallback? onDelete;

  @override
  State<HealthForm> createState() => _HealthFormState();
}

class _HealthFormState extends State<HealthForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weightController;
  late final TextEditingController _waterController;
  late final TextEditingController _exerciseTypeController;
  late final TextEditingController _noteController;
  late final TextEditingController _physicalStateDescriptionController;
  int? _sleepDurationMinutes;
  int? _exerciseDurationMinutes;
  int? _waterIntakeMl;
  int? _physicalStateScore;
  int _sleepStep = 15;
  int _exerciseStep = 15;
  int _waterStep = 250;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController();
    _waterController = TextEditingController();
    _exerciseTypeController = TextEditingController();
    _noteController = TextEditingController();
    _physicalStateDescriptionController = TextEditingController();
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
    _physicalStateDescriptionController.dispose();
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
          DurationStepInput(
            key: const ValueKey('healthSleepDurationField'),
            label: '睡眠时长',
            icon: Icons.bedtime_outlined,
            value: _sleepDurationMinutes,
            selectedStep: _sleepStep,
            onStepChanged: (value) => setState(() => _sleepStep = value),
            onChanged: (value) => setState(() => _sleepDurationMinutes = value),
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
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cup = WaterCupIndicator(waterIntakeMl: _waterIntakeMl);
                  final controls = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.water_drop_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '饮水',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      QuickIncrementControl(
                        value: _waterIntakeMl,
                        stepOptions: const [100, 250, 500],
                        selectedStep: _waterStep,
                        unit: 'ml',
                        minimumValue: 0,
                        label: '饮水量',
                        onStepChanged: (value) =>
                            setState(() => _waterStep = value),
                        onChanged: _setWater,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const ValueKey('healthWaterField'),
                        controller: _waterController,
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '精确饮水量（ml，可选）',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateWater,
                        onChanged: (value) {
                          final parsed = int.tryParse(value.trim());
                          setState(() {
                            _waterIntakeMl = value.trim().isEmpty
                                ? null
                                : parsed != null && parsed >= 0
                                ? parsed
                                : _waterIntakeMl;
                          });
                        },
                      ),
                    ],
                  );
                  if (constraints.maxWidth < 560) {
                    return Column(
                      children: [cup, const SizedBox(height: 12), controls],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 180, child: cup),
                      const SizedBox(width: 20),
                      Expanded(child: controls),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          DurationStepInput(
            key: const ValueKey('healthExerciseDurationField'),
            label: '运动时长',
            icon: Icons.directions_run_outlined,
            value: _exerciseDurationMinutes,
            selectedStep: _exerciseStep,
            onStepChanged: (value) => setState(() => _exerciseStep = value),
            onChanged: (value) =>
                setState(() => _exerciseDurationMinutes = value),
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
          WellbeingRatingField(
            key: const ValueKey('healthPhysicalStateField'),
            label: '身体状态',
            icon: Icons.accessibility_new_outlined,
            value: _physicalStateScore,
            description: _physicalStateDescriptionController.text,
            descriptionHint: '一句话记下身体感受',
            onScoreChanged: (value) =>
                setState(() => _physicalStateScore = value),
            onDescriptionChanged: (value) {
              _physicalStateDescriptionController.text = value;
              setState(() {});
            },
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
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.onDelete != null)
                TextButton.icon(
                  key: const ValueKey('deleteTodayHealthButton'),
                  onPressed: widget.isSaving || _isSubmitting
                      ? null
                      : widget.onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                ),
              FilledButton.icon(
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
            ],
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
      waterIntakeMl: _waterIntakeMl,
      exerciseDurationMinutes: _exerciseDurationMinutes,
      exerciseType: _exerciseTypeController.text,
      physicalStateScore: _physicalStateScore,
      physicalStateDescription: _physicalStateDescriptionController.text,
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

  double? _parseDouble(String value) {
    final text = value.trim();
    return text.isEmpty ? null : double.parse(text);
  }

  void _syncFromEntry(HealthEntry entry) {
    _sleepDurationMinutes = entry.sleepDurationMinutes;
    _exerciseDurationMinutes = entry.exerciseDurationMinutes;
    _weightController.text = entry.weightKg?.toString() ?? '';
    _waterController.text = entry.waterIntakeMl?.toString() ?? '';
    _waterIntakeMl = entry.waterIntakeMl;
    _exerciseTypeController.text = entry.exerciseType ?? '';
    _physicalStateScore = entry.physicalStateScore;
    _physicalStateDescriptionController.text =
        entry.physicalStateDescription ?? '';
    _noteController.text = entry.note ?? '';
  }

  void _setWater(int? value) {
    setState(() {
      _waterIntakeMl = value;
      _waterController.text = value?.toString() ?? '';
    });
  }
}
