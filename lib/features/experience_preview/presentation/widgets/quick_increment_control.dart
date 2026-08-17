import 'package:flutter/material.dart';

import '../../../../core/theme/app_layout.dart';

class QuickIncrementControl extends StatefulWidget {
  const QuickIncrementControl({
    required this.value,
    required this.stepOptions,
    required this.selectedStep,
    required this.unit,
    required this.minimumValue,
    required this.onChanged,
    super.key,
    this.maximumValue,
    this.allowNull = true,
    this.onStepChanged,
    this.label = '数值',
    this.valueFormatter,
  }) : assert(stepOptions.length > 0);

  final int? value;
  final List<int> stepOptions;
  final int selectedStep;
  final String unit;
  final int minimumValue;
  final int? maximumValue;
  final ValueChanged<int?> onChanged;
  final ValueChanged<int>? onStepChanged;
  final bool allowNull;
  final String label;
  final String Function(int? value)? valueFormatter;

  @override
  State<QuickIncrementControl> createState() => _QuickIncrementControlState();
}

class _QuickIncrementControlState extends State<QuickIncrementControl> {
  late int? _value = widget.value;
  late int _step = widget.selectedStep;

  @override
  void didUpdateWidget(covariant QuickIncrementControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _value) {
      _value = widget.value;
    }
    if (widget.selectedStep != oldWidget.selectedStep) {
      _step = widget.selectedStep;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayValue =
        widget.valueFormatter?.call(_value) ??
        (_value == null ? '未记录' : '$_value ${widget.unit}');
    return Semantics(
      container: true,
      label: '当前${widget.label}$displayValue',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            displayValue,
            key: ValueKey('${widget.label}Value'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              Semantics(
                button: true,
                label: '减少 $_step ${widget.unit}',
                child: OutlinedButton.icon(
                  key: ValueKey('${widget.label}Decrease'),
                  style: const ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(
                      Size(0, AppLayout.minimumTouchTarget),
                    ),
                  ),
                  onPressed: _decrease,
                  icon: const Icon(Icons.remove),
                  label: Text('−$_step ${widget.unit}'),
                ),
              ),
              Semantics(
                button: true,
                label: '增加 $_step ${widget.unit}',
                child: FilledButton.icon(
                  key: ValueKey('${widget.label}Increase'),
                  style: const ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(
                      Size(0, AppLayout.minimumTouchTarget),
                    ),
                  ),
                  onPressed: _increase,
                  icon: const Icon(Icons.add),
                  label: Text('+$_step ${widget.unit}'),
                ),
              ),
              Semantics(
                button: true,
                label: '选择${widget.label}步长，当前 $_step ${widget.unit}',
                child: OutlinedButton.icon(
                  key: ValueKey('${widget.label}StepSelector'),
                  style: const ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(
                      Size(0, AppLayout.minimumTouchTarget),
                    ),
                  ),
                  onPressed: _selectStep,
                  icon: const Icon(Icons.tune),
                  label: Text('步长 $_step ${widget.unit}'),
                ),
              ),
              if (widget.allowNull)
                IconButton.outlined(
                  key: ValueKey('${widget.label}Clear'),
                  tooltip: '清空${widget.label}',
                  onPressed: _value == null ? null : _clear,
                  icon: const Icon(Icons.clear),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _increase() {
    final base = _value ?? widget.minimumValue;
    final maximum = widget.maximumValue;
    final next = maximum == null
        ? base + _step
        : (base + _step).clamp(widget.minimumValue, maximum);
    _emit(next);
  }

  void _decrease() {
    final current = _value;
    if (current == null) return;
    _emit((current - _step).clamp(widget.minimumValue, current));
  }

  void _clear() => _emit(null);

  void _emit(int? next) {
    setState(() => _value = next);
    widget.onChanged(next);
  }

  Future<void> _selectStep() async {
    final width = MediaQuery.sizeOf(context).width;
    final selected = width < AppLayout.navigationRailBreakpoint
        ? await showModalBottomSheet<int>(
            context: context,
            showDragHandle: true,
            builder: (context) => SafeArea(
              child: ListView(
                key: const ValueKey('incrementStepBottomSheet'),
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.xs,
                    ),
                    child: Text(
                      '选择${widget.label}步长',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final option in widget.stepOptions)
                    ListTile(
                      key: ValueKey('${widget.label}Step$option'),
                      leading: Icon(
                        option == _step
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      title: Text('$option ${widget.unit}'),
                      onTap: () => Navigator.of(context).pop(option),
                    ),
                ],
              ),
            ),
          )
        : await showMenu<int>(
            context: context,
            position: const RelativeRect.fromLTRB(240, 160, 24, 24),
            items: [
              for (final option in widget.stepOptions)
                PopupMenuItem<int>(
                  key: ValueKey('${widget.label}Step$option'),
                  value: option,
                  child: Text('$option ${widget.unit}'),
                ),
            ],
          );
    if (!mounted || selected == null || selected == _step) return;
    setState(() => _step = selected);
    widget.onStepChanged?.call(selected);
  }
}
