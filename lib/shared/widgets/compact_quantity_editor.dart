import 'package:flutter/material.dart';

import '../../core/theme/app_layout.dart';

class CompactQuantityEditor extends StatefulWidget {
  const CompactQuantityEditor({
    required this.label,
    required this.icon,
    required this.value,
    required this.unit,
    required this.onChanged,
    this.allowDecimal = false,
    this.allowZero = true,
    this.allowAdd = true,
    this.maximumValue,
    this.resetToken,
    super.key,
  });

  final String label;
  final IconData icon;
  final num? value;
  final String unit;
  final ValueChanged<num?> onChanged;
  final bool allowDecimal;
  final bool allowZero;
  final bool allowAdd;
  final num? maximumValue;
  final Object? resetToken;

  @override
  State<CompactQuantityEditor> createState() => _CompactQuantityEditorState();
}

class _CompactQuantityEditorState extends State<CompactQuantityEditor> {
  late final TextEditingController _controller = TextEditingController();
  late num? _value = widget.value;
  num? _undoValue;
  bool _canUndo = false;

  @override
  void initState() {
    super.initState();
    _writeValue(widget.value);
  }

  @override
  void didUpdateWidget(covariant CompactQuantityEditor oldWidget) {
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valueText = _value == null
        ? '未记录'
        : '${_formatNumber(_value!)} ${widget.unit}';
    return Semantics(
      key: ValueKey('${widget.label}QuantitySemantics'),
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
                  key: ValueKey('${widget.label}QuantityValue'),
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
                  width: 160,
                  child: TextFormField(
                    key: ValueKey('${widget.label}ValueField'),
                    controller: _controller,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: widget.allowDecimal,
                      signed: true,
                    ),
                    textInputAction: TextInputAction.done,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: '数值',
                      suffixText: widget.unit,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    validator: _validate,
                    onChanged: (_) => _handleDirectInput(),
                  ),
                ),
                if (widget.allowAdd)
                  _QuantityActionButton(
                    key: ValueKey('${widget.label}Add'),
                    tooltip: '增加${widget.label}',
                    semanticLabel: '增加${widget.label}',
                    icon: Icons.add_circle_outline,
                    onPressed: _openAddDialog,
                  ),
                _QuantityActionButton(
                  key: ValueKey('${widget.label}Clear'),
                  tooltip: '清空${widget.label}',
                  semanticLabel: '清空${widget.label}',
                  icon: Icons.clear,
                  onPressed: _controller.text.isEmpty ? null : _clear,
                ),
                _QuantityActionButton(
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

  void _handleDirectInput() {
    setState(() {});
    final parsed = _parse(_controller.text);
    if (!parsed.valid || parsed.value == _value) return;
    _emit(parsed.value, updateField: false);
  }

  Future<void> _openAddDialog() async {
    final amount = await showDialog<num>(
      context: context,
      builder: (context) => _QuantityAddDialog(
        label: widget.label,
        unit: widget.unit,
        allowDecimal: widget.allowDecimal,
      ),
    );
    if (!mounted || amount == null) return;
    num next = (_value ?? 0) + amount;
    final maximum = widget.maximumValue;
    if (maximum != null && next > maximum) next = maximum;
    if (!widget.allowDecimal) next = next.toInt();
    _emit(next);
  }

  void _clear() => _emit(null);

  void _undo() {
    if (!_canUndo) return;
    final previous = _undoValue;
    setState(() {
      _value = previous;
      _undoValue = null;
      _canUndo = false;
      _writeValue(previous);
    });
    widget.onChanged(previous);
  }

  void _emit(num? next, {bool updateField = true}) {
    final previous = _value;
    setState(() {
      _undoValue = previous;
      _canUndo = true;
      _value = next;
      if (updateField) _writeValue(next);
    });
    widget.onChanged(next);
  }

  void _resetTo(num? value) {
    setState(() {
      _value = value;
      _undoValue = null;
      _canUndo = false;
      _writeValue(value);
    });
  }

  void _scheduleReset(num? value) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resetTo(value);
    });
  }

  void _writeValue(num? value) {
    _controller.text = value == null ? '' : _formatNumber(value);
  }

  ({bool valid, num? value}) _parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return (valid: true, value: null);
    final value = widget.allowDecimal
        ? double.tryParse(text)
        : int.tryParse(text);
    if (value == null || value < 0 || (!widget.allowZero && value == 0)) {
      return (valid: false, value: null);
    }
    final maximum = widget.maximumValue;
    if (maximum != null && value > maximum) {
      return (valid: false, value: null);
    }
    return (valid: true, value: value);
  }

  String? _validate(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = _parse(text);
    if (!parsed.valid) {
      if (widget.maximumValue != null) {
        return '请输入不超过 ${_formatNumber(widget.maximumValue!)} 的${widget.allowDecimal ? '数字' : '整数'}';
      }
      return widget.allowZero
          ? '请输入非负${widget.allowDecimal ? '数字' : '整数'}'
          : '请输入大于 0 的数字';
    }
    return null;
  }
}

class _QuantityActionButton extends StatelessWidget {
  const _QuantityActionButton({
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

class _QuantityAddDialog extends StatefulWidget {
  const _QuantityAddDialog({
    required this.label,
    required this.unit,
    required this.allowDecimal,
  });

  final String label;
  final String unit;
  final bool allowDecimal;

  @override
  State<_QuantityAddDialog> createState() => _QuantityAddDialogState();
}

class _QuantityAddDialogState extends State<_QuantityAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: ValueKey('${widget.label}AddDialog'),
      title: Text('增加${widget.label}'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: ValueKey('${widget.label}AddValueField'),
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(
            decimal: widget.allowDecimal,
            signed: true,
          ),
          decoration: InputDecoration(
            labelText: '增加数值',
            suffixText: widget.unit,
          ),
          validator: (raw) {
            final text = raw?.trim() ?? '';
            final value = widget.allowDecimal
                ? double.tryParse(text)
                : int.tryParse(text);
            if (value == null || value <= 0) return '请输入大于 0 的数字';
            return null;
          },
          onFieldSubmitted: (_) => _confirm(),
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
    final value = widget.allowDecimal
        ? double.parse(_controller.text.trim())
        : int.parse(_controller.text.trim());
    Navigator.of(context).pop<num>(value);
  }
}

String _formatNumber(num value) {
  if (value is int || value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}
