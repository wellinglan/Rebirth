import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MetricDescriptionField extends StatefulWidget {
  const MetricDescriptionField({
    required this.label,
    required this.value,
    required this.hintText,
    required this.onChanged,
    this.resetToken,
    super.key,
  });

  final String label;
  final String value;
  final String hintText;
  final ValueChanged<String> onChanged;
  final Object? resetToken;

  @override
  State<MetricDescriptionField> createState() => _MetricDescriptionFieldState();
}

class _MetricDescriptionFieldState extends State<MetricDescriptionField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  late bool _expanded = widget.value.trim().isNotEmpty;

  @override
  void didUpdateWidget(covariant MetricDescriptionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldReset = widget.resetToken != oldWidget.resetToken;
    final valueChangedExternally =
        widget.value != oldWidget.value && widget.value != _controller.text;
    if (shouldReset || valueChangedExternally) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _controller.value = TextEditingValue(
            text: widget.value,
            selection: TextSelection.collapsed(offset: widget.value.length),
          );
          _expanded = widget.value.trim().isNotEmpty;
        });
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: ValueKey('${widget.label}DescriptionAdd'),
          onPressed: () => setState(() => _expanded = true),
          icon: const Icon(Icons.add_comment_outlined, size: 20),
          label: const Text('添加一句话描述'),
        ),
      );
    }

    return TextFormField(
      key: ValueKey('${widget.label}Description'),
      controller: _controller,
      maxLength: 80,
      maxLengthEnforcement: MaxLengthEnforcement.none,
      maxLines: 1,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: '${widget.label}描述（可选）',
        hintText: widget.hintText,
        counterText: '',
        suffixIcon: IconButton(
          key: ValueKey('${widget.label}DescriptionClear'),
          tooltip: '清空${widget.label}描述',
          onPressed: _clear,
          icon: const Icon(Icons.clear),
        ),
      ),
      validator: (value) {
        if ((value?.trim().length ?? 0) > 80) {
          return '最多输入 80 个字符';
        }
        return null;
      },
      onChanged: widget.onChanged,
    );
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() => _expanded = false);
  }
}
