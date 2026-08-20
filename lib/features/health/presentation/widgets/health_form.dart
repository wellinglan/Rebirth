import 'package:flutter/material.dart';
import 'package:rebirth/features/health/domain/health_entry.dart';
import 'package:rebirth/features/health/domain/health_save_data.dart';
import 'package:rebirth/shared/widgets/compact_duration_editor.dart';
import 'package:rebirth/shared/widgets/compact_quantity_editor.dart';
import 'package:rebirth/shared/widgets/metric_description_field.dart';
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
  late final TextEditingController _exerciseTypeController;
  late final TextEditingController _noteController;
  late final TextEditingController _sleepDescriptionController;
  late final TextEditingController _weightDescriptionController;
  late final TextEditingController _waterDescriptionController;
  late final TextEditingController _exerciseDescriptionController;
  late final TextEditingController _physicalStateDescriptionController;
  int? _sleepDurationMinutes;
  double? _weightKg;
  int? _exerciseDurationMinutes;
  int? _waterIntakeMl;
  int? _physicalStateScore;
  int _metricEditorResetToken = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _exerciseTypeController = TextEditingController();
    _noteController = TextEditingController();
    _sleepDescriptionController = TextEditingController();
    _weightDescriptionController = TextEditingController();
    _waterDescriptionController = TextEditingController();
    _exerciseDescriptionController = TextEditingController();
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
    _exerciseTypeController.dispose();
    _noteController.dispose();
    _sleepDescriptionController.dispose();
    _weightDescriptionController.dispose();
    _waterDescriptionController.dispose();
    _exerciseDescriptionController.dispose();
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
          CompactDurationEditor(
            key: const ValueKey('healthSleepDurationField'),
            label: '睡眠时长',
            icon: Icons.bedtime_outlined,
            value: _sleepDurationMinutes,
            resetToken: _metricEditorResetToken,
            onChanged: (value) => setState(() => _sleepDurationMinutes = value),
          ),
          MetricDescriptionField(
            label: '睡眠时长',
            value: _sleepDescriptionController.text,
            hintText: '记录昨晚的睡眠感受',
            resetToken: _metricEditorResetToken,
            onChanged: (value) {
              _sleepDescriptionController.text = value;
              setState(() {});
            },
          ),
          const Divider(height: 28),
          CompactQuantityEditor(
            key: const ValueKey('healthWeightField'),
            label: '体重',
            icon: Icons.monitor_weight_outlined,
            value: _weightKg,
            unit: 'kg',
            allowDecimal: true,
            allowZero: false,
            allowAdd: false,
            resetToken: _metricEditorResetToken,
            onChanged: (value) => setState(() => _weightKg = value?.toDouble()),
          ),
          MetricDescriptionField(
            label: '体重',
            value: _weightDescriptionController.text,
            hintText: '补充本次体重记录',
            resetToken: _metricEditorResetToken,
            onChanged: (value) {
              _weightDescriptionController.text = value;
              setState(() {});
            },
          ),
          const Divider(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final cup = WaterCupIndicator(waterIntakeMl: _waterIntakeMl);
              final editor = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CompactQuantityEditor(
                    key: const ValueKey('healthWaterField'),
                    label: '饮水',
                    icon: Icons.water_drop_outlined,
                    value: _waterIntakeMl,
                    unit: 'ml',
                    resetToken: _metricEditorResetToken,
                    onChanged: (value) =>
                        setState(() => _waterIntakeMl = value?.toInt()),
                  ),
                  MetricDescriptionField(
                    label: '饮水',
                    value: _waterDescriptionController.text,
                    hintText: '记录今天的饮水情况',
                    resetToken: _metricEditorResetToken,
                    onChanged: (value) {
                      _waterDescriptionController.text = value;
                      setState(() {});
                    },
                  ),
                ],
              );
              if (constraints.maxWidth < 560) {
                return Column(
                  children: [cup, const SizedBox(height: 8), editor],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 150, child: cup),
                  const SizedBox(width: 20),
                  Expanded(child: editor),
                ],
              );
            },
          ),
          const Divider(height: 28),
          CompactDurationEditor(
            key: const ValueKey('healthExerciseDurationField'),
            label: '运动时长',
            icon: Icons.directions_run_outlined,
            value: _exerciseDurationMinutes,
            resetToken: _metricEditorResetToken,
            onChanged: (value) =>
                setState(() => _exerciseDurationMinutes = value),
          ),
          MetricDescriptionField(
            label: '运动时长',
            value: _exerciseDescriptionController.text,
            hintText: '记录运动内容或感受',
            resetToken: _metricEditorResetToken,
            onChanged: (value) {
              _exerciseDescriptionController.text = value;
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
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
            descriptionHint: '用一句话描述今天的身体感受',
            resetToken: _metricEditorResetToken,
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
      sleepDescription: _sleepDescriptionController.text,
      weightKg: _weightKg,
      weightDescription: _weightDescriptionController.text,
      waterIntakeMl: _waterIntakeMl,
      waterDescription: _waterDescriptionController.text,
      exerciseDurationMinutes: _exerciseDurationMinutes,
      exerciseDescription: _exerciseDescriptionController.text,
      exerciseType: _exerciseTypeController.text,
      physicalStateScore: _physicalStateScore,
      physicalStateDescription: _physicalStateDescriptionController.text,
      note: _noteController.text,
    );

    setState(() => _isSubmitting = true);
    try {
      await widget.onSave(data);
      if (mounted) {
        setState(() => _metricEditorResetToken++);
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

  void _syncFromEntry(HealthEntry entry) {
    _sleepDurationMinutes = entry.sleepDurationMinutes;
    _sleepDescriptionController.text = entry.sleepDescription ?? '';
    _exerciseDurationMinutes = entry.exerciseDurationMinutes;
    _exerciseDescriptionController.text = entry.exerciseDescription ?? '';
    _weightKg = entry.weightKg;
    _weightDescriptionController.text = entry.weightDescription ?? '';
    _waterIntakeMl = entry.waterIntakeMl;
    _waterDescriptionController.text = entry.waterDescription ?? '';
    _exerciseTypeController.text = entry.exerciseType ?? '';
    _physicalStateScore = entry.physicalStateScore;
    _physicalStateDescriptionController.text =
        entry.physicalStateDescription ?? '';
    _noteController.text = entry.note ?? '';
    _metricEditorResetToken++;
  }
}
