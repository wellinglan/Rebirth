import 'package:flutter/material.dart';

class DurationInputField extends StatefulWidget {
  const DurationInputField({
    required this.label,
    required this.initialMinutes,
    required this.onChanged,
    this.quickValues = const <int>[],
    super.key,
  });

  final String label;
  final int? initialMinutes;
  final ValueChanged<int?> onChanged;
  final List<int> quickValues;

  @override
  State<DurationInputField> createState() => _DurationInputFieldState();
}

class _DurationInputFieldState extends State<DurationInputField> {
  final _hoursFieldKey = GlobalKey<FormFieldState<String>>();
  final _minutesFieldKey = GlobalKey<FormFieldState<String>>();
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;

  @override
  void initState() {
    super.initState();
    _hoursController = TextEditingController();
    _minutesController = TextEditingController();
    _setTotalMinutes(widget.initialMinutes, notify: false);
  }

  @override
  void didUpdateWidget(covariant DurationInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMinutes != widget.initialMinutes) {
      _setTotalMinutes(widget.initialMinutes, notify: false);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                key: _hoursFieldKey,
                controller: _hoursController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '小时数',
                  border: OutlineInputBorder(),
                ),
                validator: _validateHours,
                onChanged: (_) => _emitIfValid(),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 20, 8, 0),
              child: Text('小时'),
            ),
            Expanded(
              child: TextFormField(
                key: _minutesFieldKey,
                controller: _minutesController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '分钟数',
                  border: OutlineInputBorder(),
                ),
                validator: _validateMinutes,
                onChanged: (_) => _emitIfValid(),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 20, 0, 0),
              child: Text('分钟'),
            ),
          ],
        ),
        if (widget.quickValues.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final totalMinutes in widget.quickValues)
                ActionChip(
                  label: Text(_formatQuickValue(totalMinutes)),
                  onPressed: () => _applyQuickValue(totalMinutes),
                ),
            ],
          ),
        ],
      ],
    );
  }

  String? _validateHours(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }

    final hours = int.tryParse(text);
    if (hours == null || hours < 0) {
      return '请输入非负整数';
    }
    return null;
  }

  String? _validateMinutes(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }

    final minutes = int.tryParse(text);
    if (minutes == null || minutes < 0) {
      return '请输入 0–59 的整数';
    }
    if (minutes >= 60) {
      return '分钟需小于 60';
    }
    return null;
  }

  void _emitIfValid() {
    if (_validateHours(_hoursController.text) != null ||
        _validateMinutes(_minutesController.text) != null) {
      return;
    }

    final hoursText = _hoursController.text.trim();
    final minutesText = _minutesController.text.trim();
    if (hoursText.isEmpty && minutesText.isEmpty) {
      widget.onChanged(null);
      return;
    }

    final hours = hoursText.isEmpty ? 0 : int.parse(hoursText);
    final minutes = minutesText.isEmpty ? 0 : int.parse(minutesText);
    widget.onChanged(hours * 60 + minutes);
  }

  void _applyQuickValue(int totalMinutes) {
    _setTotalMinutes(totalMinutes, notify: true);
    _hoursFieldKey.currentState?.validate();
    _minutesFieldKey.currentState?.validate();
  }

  void _setTotalMinutes(int? totalMinutes, {required bool notify}) {
    if (totalMinutes == null) {
      _hoursController.text = '';
      _minutesController.text = '';
    } else {
      _hoursController.text = (totalMinutes ~/ 60).toString();
      _minutesController.text = (totalMinutes % 60).toString();
    }

    if (notify) {
      widget.onChanged(totalMinutes);
    }
  }

  String _formatQuickValue(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) {
      return '$minutes分钟';
    }
    if (minutes == 0) {
      return '$hours小时';
    }
    return '$hours小时$minutes分钟';
  }
}
