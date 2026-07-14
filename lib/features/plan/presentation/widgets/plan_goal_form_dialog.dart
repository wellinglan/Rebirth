import 'package:flutter/material.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_goal_save_data.dart';

import 'plan_goal_labels.dart';

class PlanGoalFormDialog extends StatefulWidget {
  const PlanGoalFormDialog({
    required this.existingGoal,
    required this.onSubmit,
    super.key,
  });

  final PlanGoal? existingGoal;
  final Future<void> Function(PlanGoalSaveData data) onSubmit;

  @override
  State<PlanGoalFormDialog> createState() => _PlanGoalFormDialogState();
}

class _PlanGoalFormDialogState extends State<PlanGoalFormDialog> {
  static const _dateTimeService = DateTimeService();

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _startDateController;
  late final TextEditingController _targetDateController;
  late final TextEditingController _sortOrderController;
  late PlanGoalLevel _goalLevel;
  late PlanGoalStatus _status;
  var _isSaving = false;

  bool get _isEditing => widget.existingGoal != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.existingGoal;
    _titleController = TextEditingController(text: goal?.title ?? '');
    _descriptionController = TextEditingController(
      text: goal?.description ?? '',
    );
    _startDateController = TextEditingController(text: goal?.startDate ?? '');
    _targetDateController = TextEditingController(text: goal?.targetDate ?? '');
    _sortOrderController = TextEditingController(
      text: (goal?.sortOrder ?? 0).toString(),
    );
    _goalLevel = goal?.goalLevel ?? PlanGoalLevel.month;
    _status = goal?.status ?? PlanGoalStatus.notStarted;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _startDateController.dispose();
    _targetDateController.dispose();
    _sortOrderController.dispose();
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
          width: 520,
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
                              setState(() => _goalLevel = value);
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
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('planGoalStartDateField'),
                    controller: _startDateController,
                    keyboardType: TextInputType.datetime,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '开始日期（可选）',
                      hintText: 'YYYY-MM-DD',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateDate,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('planGoalTargetDateField'),
                    controller: _targetDateController,
                    keyboardType: TextInputType.datetime,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '目标日期（可选）',
                      hintText: 'YYYY-MM-DD',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateTargetDate,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('planGoalSortOrderField'),
                    controller: _sortOrderController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: '排序',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final sortOrder = int.tryParse(value?.trim() ?? '');
                      return sortOrder == null || sortOrder < 0
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

  String? _validateDate(String? value) {
    final date = value?.trim() ?? '';
    if (date.isEmpty) {
      return null;
    }
    return _dateTimeService.isValidLocalDateString(date)
        ? null
        : '请输入 YYYY-MM-DD 格式日期';
  }

  String? _validateTargetDate(String? value) {
    final formatError = _validateDate(value);
    if (formatError != null) {
      return formatError;
    }
    final startDate = _nullableText(_startDateController.text);
    final targetDate = _nullableText(value ?? '');
    if (startDate != null &&
        targetDate != null &&
        _dateTimeService.isValidLocalDateString(startDate) &&
        targetDate.compareTo(startDate) < 0) {
      return '目标日期不能早于开始日期';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final data = PlanGoalSaveData(
      parentGoalId: widget.existingGoal?.parentGoalId,
      title: _titleController.text,
      description: _descriptionController.text,
      goalLevel: _goalLevel,
      status: _status,
      startDate: _nullableText(_startDateController.text),
      targetDate: _nullableText(_targetDateController.text),
      sortOrder: int.parse(_sortOrderController.text.trim()),
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

  String? _nullableText(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
}
