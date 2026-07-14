import 'package:flutter/material.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_goal_date_policy.dart';
import 'package:rebirth/features/plan/domain/plan_goal_save_data.dart';

import 'plan_date_parts_field.dart';
import 'plan_goal_labels.dart';

class PlanGoalFormDialog extends StatefulWidget {
  const PlanGoalFormDialog({
    required this.existingGoal,
    required this.parentGoalId,
    required this.defaultStartDate,
    required this.defaultGoalLevel,
    required this.onSubmit,
    super.key,
  });

  final PlanGoal? existingGoal;
  final String? parentGoalId;
  final String defaultStartDate;
  final PlanGoalLevel defaultGoalLevel;
  final Future<void> Function(PlanGoalSaveData data) onSubmit;

  @override
  State<PlanGoalFormDialog> createState() => _PlanGoalFormDialogState();
}

class _PlanGoalFormDialogState extends State<PlanGoalFormDialog> {
  static const _datePolicy = PlanGoalDatePolicy();

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priorityController;
  late PlanGoalLevel _goalLevel;
  late PlanGoalStatus _status;
  late String? _startDate;
  late String? _targetDate;
  var _isSaving = false;

  bool get _isEditing => widget.existingGoal != null;
  bool get _targetDateIsEditable => _goalLevel == PlanGoalLevel.custom;

  @override
  void initState() {
    super.initState();
    final goal = widget.existingGoal;
    _titleController = TextEditingController(text: goal?.title ?? '');
    _descriptionController = TextEditingController(
      text: goal?.description ?? '',
    );
    _priorityController = TextEditingController(
      text: (goal?.sortOrder ?? 0).toString(),
    );
    _goalLevel = goal?.goalLevel ?? widget.defaultGoalLevel;
    _status = goal?.status ?? PlanGoalStatus.notStarted;
    _startDate = goal?.startDate ?? widget.defaultStartDate;
    _targetDate = _goalLevel == PlanGoalLevel.custom
        ? goal?.targetDate
        : _calculateTargetDate();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: AlertDialog(
        key: const ValueKey('planGoalFormDialog'),
        title: Text(_isEditing ? '编辑目标' : '新建目标'),
        content: SizedBox(
          width: 600,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: const ValueKey('planGoalTitleField'),
                    controller: _titleController,
                    autofocus: !_isEditing,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '目标标题',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '目标标题不能为空'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('planGoalDescriptionField'),
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: '描述（可选）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<PlanGoalLevel>(
                    key: const ValueKey('planGoalLevelField'),
                    initialValue: _goalLevel,
                    decoration: const InputDecoration(
                      labelText: '目标层级',
                      border: OutlineInputBorder(),
                    ),
                    items: PlanGoalLevel.values
                        .map((level) {
                          return DropdownMenuItem(
                            value: level,
                            child: Text(planGoalLevelLabel(level)),
                          );
                        })
                        .toList(growable: false),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value != null) {
                              _changeGoalLevel(value);
                            }
                          },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<PlanGoalStatus>(
                    key: const ValueKey('planGoalStatusField'),
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: '状态',
                      border: OutlineInputBorder(),
                    ),
                    items: PlanGoalStatus.values
                        .map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(planGoalStatusLabel(status)),
                          );
                        })
                        .toList(growable: false),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _status = value);
                            }
                          },
                  ),
                  const SizedBox(height: 20),
                  PlanDatePartsField(
                    key: const ValueKey('planGoalStartDateField'),
                    fieldId: 'planStartDate',
                    label: '开始日期',
                    value: _startDate,
                    enabled: !_isSaving,
                    isRequired: true,
                    onChanged: _changeStartDate,
                  ),
                  const SizedBox(height: 20),
                  PlanDatePartsField(
                    key: const ValueKey('planGoalTargetDateField'),
                    fieldId: 'planTargetDate',
                    label: _targetDateIsEditable ? '目标日期（可选）' : '目标日期（自动）',
                    value: _targetDate,
                    enabled: !_isSaving && _targetDateIsEditable,
                    validator: _validateTargetDate,
                    onChanged: (value) => setState(() => _targetDate = value),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('planGoalPriorityField'),
                    controller: _priorityController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: '优先级',
                      helperText: '数值越小越靠前',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final priority = int.tryParse(value?.trim() ?? '');
                      return priority == null || priority < 0
                          ? '请输入非负整数'
                          : null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('cancelPlanGoalButton'),
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            key: const ValueKey('submitPlanGoalButton'),
            onPressed: _isSaving ? null : _submit,
            icon: _isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      key: ValueKey('planGoalSaveProgressIndicator'),
                      strokeWidth: 2,
                    ),
                  )
                : Icon(_isEditing ? Icons.save_outlined : Icons.add),
            label: Text(
              _isSaving
                  ? '保存中...'
                  : _isEditing
                  ? '保存修改'
                  : '创建目标',
            ),
          ),
        ],
      ),
    );
  }

  void _changeGoalLevel(PlanGoalLevel value) {
    setState(() {
      _goalLevel = value;
      if (value != PlanGoalLevel.custom) {
        _targetDate = _calculateTargetDate();
      }
    });
  }

  void _changeStartDate(String? value) {
    setState(() {
      _startDate = value;
      if (_goalLevel != PlanGoalLevel.custom) {
        _targetDate = _calculateTargetDate();
      }
    });
  }

  String? _calculateTargetDate() {
    final startDate = _startDate;
    if (startDate == null) {
      return null;
    }
    return _datePolicy.targetDate(level: _goalLevel, startDate: startDate);
  }

  String? _validateTargetDate(String? value) {
    if (!_targetDateIsEditable || value == null || _startDate == null) {
      return null;
    }
    return value.compareTo(_startDate!) < 0 ? '目标日期不能早于开始日期' : null;
  }

  Future<void> _submit() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final data = PlanGoalSaveData(
      parentGoalId: widget.existingGoal?.parentGoalId ?? widget.parentGoalId,
      title: _titleController.text,
      description: _descriptionController.text,
      goalLevel: _goalLevel,
      status: _status,
      startDate: _startDate,
      targetDate: _targetDate,
      sortOrder: int.parse(_priorityController.text.trim()),
    );

    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(data);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(_isEditing ? '保存失败，请重试' : '创建失败，请重试')),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
