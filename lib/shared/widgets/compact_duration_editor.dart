import 'package:flutter/material.dart';

import '../../core/theme/app_layout.dart';

class CompactDurationEditor extends StatefulWidget {
  const CompactDurationEditor({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.resetToken,
    super.key,
  });

  final String label;
  final IconData icon;
  final int? value;
  final ValueChanged<int?> onChanged;
  final Object? resetToken;

  @override
  State<CompactDurationEditor> createState() => _CompactDurationEditorState();
}

class _CompactDurationEditorState extends State<CompactDurationEditor> {
  late final TextEditingController _hoursController = TextEditingController();
  late final TextEditingController _minutesController = TextEditingController();
  late int? _value = widget.value;
  int? _undoValue;
  bool _canUndo = false;

  @override
  void initState() {
    super.initState();
    _writeValue(widget.value);
  }

  @override
  void didUpdateWidget(covariant CompactDurationEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetToken != oldWidget.resetToken) {
      _scheduleReset(widget.value);
      return;
    }
    if (widget.value != oldWidget.value && widget.value != _value) {
      _scheduleReset(widget.value);
    }
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valueText = formatDurationMinutes(_value);
    return Semantics(
      key: ValueKey('${widget.label}DurationSemantics'),
      container: true,
      label: '${widget.label}，当前$valueText',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                ExcludeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.icon,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        widget.label,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
                Text(
                  valueText,
                  key: ValueKey('${widget.label}DurationValue'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.start,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                SizedBox(
                  width: 104,
                  child: TextFormField(
                    key: ValueKey('${widget.label}HoursField'),
                    controller: _hoursController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    textInputAction: TextInputAction.next,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: const InputDecoration(
                      labelText: '小时',
                      suffixText: 'h',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    validator: _validateHours,
                    onChanged: (_) => _handleDirectInput(),
                  ),
                ),
                SizedBox(
                  width: 112,
                  child: TextFormField(
                    key: ValueKey('${widget.label}MinutesField'),
                    controller: _minutesController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    textInputAction: TextInputAction.done,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: const InputDecoration(
                      labelText: '分钟',
                      suffixText: 'min',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    validator: _validateMinutes,
                    onChanged: (_) => _handleDirectInput(),
                  ),
                ),
                _ActionButton(
                  key: ValueKey('${widget.label}Add'),
                  tooltip: '增加${widget.label}',
                  semanticLabel: '增加${widget.label}',
                  icon: Icons.add_circle_outline,
                  onPressed: _openAddDialog,
                ),
                _ActionButton(
                  key: ValueKey('${widget.label}Clear'),
                  tooltip: '清空${widget.label}',
                  semanticLabel: '清空${widget.label}',
                  icon: Icons.clear,
                  onPressed: _hasInput ? _clear : null,
                ),
                _ActionButton(
                  key: ValueKey('${widget.label}Undo'),
                  tooltip: '撤回${widget.label}最近一次修改',
                  semanticLabel: '撤回${widget.label}最近一次修改',
                  icon: Icons.undo,
                  onPressed: _canUndo ? _undo : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasInput =>
      _hoursController.text.isNotEmpty || _minutesController.text.isNotEmpty;

  void _handleDirectInput() {
    setState(() {});
    final parsed = _parseDuration(
      _hoursController.text,
      _minutesController.text,
    );
    if (!parsed.valid || parsed.value == _value) return;
    _emit(parsed.value, updateFields: false);
  }

  Future<void> _openAddDialog() async {
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => _DurationAddDialog(label: widget.label),
    );
    if (!mounted || amount == null) return;
    _emit((_value ?? 0) + amount);
  }

  void _clear() => _emit(null);

  void _undo() {
    if (!_canUndo) return;
    final previous = _undoValue;
    setState(() {
      _value = previous;
      _canUndo = false;
      _undoValue = null;
      _writeValue(previous);
    });
    widget.onChanged(previous);
  }

  void _emit(int? next, {bool updateFields = true}) {
    final previous = _value;
    setState(() {
      _undoValue = previous;
      _canUndo = true;
      _value = next;
      if (updateFields) _writeValue(next);
    });
    widget.onChanged(next);
  }

  void _resetTo(int? value) {
    setState(() {
      _value = value;
      _undoValue = null;
      _canUndo = false;
      _writeValue(value);
    });
  }

  void _scheduleReset(int? value) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resetTo(value);
    });
  }

  void _writeValue(int? value) {
    if (value == null) {
      _hoursController.clear();
      _minutesController.clear();
      return;
    }
    _hoursController.text = '${value ~/ 60}';
    _minutesController.text = '${value % 60}';
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.tooltip,
    required this.semanticLabel,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final String semanticLabel;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: onPressed != null,
      child: IconButton.outlined(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        constraints: const BoxConstraints.tightFor(
          width: AppLayout.minimumTouchTarget,
          height: AppLayout.minimumTouchTarget,
        ),
      ),
    );
  }
}

class _DurationAddDialog extends StatefulWidget {
  const _DurationAddDialog({required this.label});

  final String label;

  @override
  State<_DurationAddDialog> createState() => _DurationAddDialogState();
}

class _DurationAddDialogState extends State<_DurationAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: ValueKey('${widget.label}AddDialog'),
      title: Text('增加${widget.label}'),
      content: Form(
        key: _formKey,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            SizedBox(
              width: 112,
              child: TextFormField(
                key: ValueKey('${widget.label}AddHoursField'),
                controller: _hoursController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: '小时',
                  suffixText: 'h',
                ),
                validator: _validateHours,
              ),
            ),
            SizedBox(
              width: 120,
              child: TextFormField(
                key: ValueKey('${widget.label}AddMinutesField'),
                controller: _minutesController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: '分钟',
                  suffixText: 'min',
                ),
                validator: _validateMinutes,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: ValueKey('${widget.label}ConfirmAdd'),
          onPressed: _confirm,
          child: const Text('增加'),
        ),
      ],
    );
  }

  void _confirm() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final parsed = _parseDuration(
      _hoursController.text,
      _minutesController.text,
    );
    final amount = parsed.value;
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('请输入大于 0 的时长')));
      return;
    }
    Navigator.of(context).pop(amount);
  }
}

({bool valid, int? value}) _parseDuration(String hoursRaw, String minutesRaw) {
  final hoursText = hoursRaw.trim();
  final minutesText = minutesRaw.trim();
  if (_validateHours(hoursText) != null ||
      _validateMinutes(minutesText) != null) {
    return (valid: false, value: null);
  }
  if (hoursText.isEmpty && minutesText.isEmpty) {
    return (valid: true, value: null);
  }
  return (
    valid: true,
    value:
        (int.tryParse(hoursText) ?? 0) * 60 + (int.tryParse(minutesText) ?? 0),
  );
}

String? _validateHours(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  final parsed = int.tryParse(value);
  if (parsed == null || parsed < 0) return '请输入非负整数';
  return null;
}

String? _validateMinutes(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  final parsed = int.tryParse(value);
  if (parsed == null || parsed < 0) return '请输入 0–59';
  if (parsed >= 60) return '分钟需小于 60';
  return null;
}

String formatDurationMinutes(int? value) {
  if (value == null) return '未记录';
  final hours = value ~/ 60;
  final minutes = value % 60;
  if (hours == 0) return '$minutes 分钟';
  if (minutes == 0) return '$hours 小时';
  return '$hours 小时 $minutes 分钟';
}
