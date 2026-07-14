import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rebirth/core/utils/date_time_service.dart';

enum _DatePart { year, month, day }

class PlanDatePartsField extends StatefulWidget {
  const PlanDatePartsField({
    required this.fieldId,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.isRequired = false,
    this.yearStart = 1900,
    this.yearEnd = 2200,
    this.validator,
    super.key,
  });

  final String fieldId;
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final bool isRequired;
  final int yearStart;
  final int yearEnd;
  final FormFieldValidator<String?>? validator;

  @override
  State<PlanDatePartsField> createState() => _PlanDatePartsFieldState();
}

class _PlanDatePartsFieldState extends State<PlanDatePartsField> {
  static const _dateTimeService = DateTimeService();

  final _formFieldKey = GlobalKey<FormFieldState<String?>>();
  late final TextEditingController _manualController;
  int? _year;
  int? _month;
  int? _day;
  _DatePart? _manualPart;

  @override
  void initState() {
    super.initState();
    _manualController = TextEditingController();
    _syncFromValue(widget.value);
  }

  @override
  void didUpdateWidget(covariant PlanDatePartsField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _formattedValue) {
      _syncFromValue(widget.value);
      _manualPart = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _formFieldKey.currentState?.didChange(_formattedValue);
        }
      });
    }
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String?>(
      key: _formFieldKey,
      initialValue: _formattedValue,
      validator: (_) {
        final manualError = _manualValueError();
        if (manualError != null) return manualError;
        final value = _formattedValue;
        if (widget.isRequired && value == null) return '请选择日期';
        return widget.validator?.call(value);
      },
      builder: (field) {
        final colors = Theme.of(context).colorScheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildPart(_DatePart.year)),
                const SizedBox(width: 8),
                Expanded(child: _buildPart(_DatePart.month)),
                const SizedBox(width: 8),
                Expanded(child: _buildPart(_DatePart.day)),
                const SizedBox(width: 4),
                IconButton(
                  key: ValueKey('${widget.fieldId}Clear'),
                  tooltip: '清空${widget.label}',
                  onPressed: widget.enabled ? _clear : null,
                  icon: const Icon(Icons.clear),
                ),
              ],
            ),
            if (field.errorText != null) ...[
              const SizedBox(height: 6),
              Text(
                field.errorText!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPart(_DatePart part) {
    if (_manualPart == part) {
      return TextFormField(
        key: ValueKey('${widget.fieldId}Manual${_partName(part)}'),
        controller: _manualController,
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: _partLabel(part),
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => _formFieldKey.currentState?.validate(),
        onFieldSubmitted: (_) => _commitManual(part),
        onTapOutside: (_) => _commitManual(part),
      );
    }

    final value = _valueFor(part);
    return GestureDetector(
      key: ValueKey('${widget.fieldId}${_partName(part)}'),
      onTap: widget.enabled ? () => _openPicker(part) : null,
      onDoubleTap: widget.enabled ? () => _beginManual(part) : null,
      child: InputDecorator(
        isEmpty: value == null,
        decoration: InputDecoration(
          labelText: _partLabel(part),
          enabled: widget.enabled,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.expand_more, size: 18),
        ),
        child: Text(value?.toString() ?? '--'),
      ),
    );
  }

  Future<void> _openPicker(_DatePart part) async {
    final values = _valuesFor(part);
    final currentValue = _valueFor(part);
    final initialIndex = currentValue == null
        ? 0
        : math.max(0, currentValue - values.first);
    final controller = ScrollController(initialScrollOffset: initialIndex * 48);
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SizedBox(
          height: 380,
          child: Column(
            children: [
              Text(
                '选择${_partLabel(part)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  key: ValueKey('${widget.fieldId}${_partName(part)}Picker'),
                  controller: controller,
                  itemExtent: 48,
                  itemCount: values.length,
                  itemBuilder: (context, index) {
                    final value = values[index];
                    return ListTile(
                      key: ValueKey(
                        '${widget.fieldId}${_partName(part)}Option$value',
                      ),
                      title: Text('$value', textAlign: TextAlign.center),
                      selected: value == currentValue,
                      onTap: () => Navigator.of(context).pop(value),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (selected != null && mounted) {
      _changePart(part, selected);
    }
  }

  List<int> _valuesFor(_DatePart part) {
    return switch (part) {
      _DatePart.year => List<int>.generate(
        widget.yearEnd - widget.yearStart + 1,
        (index) => widget.yearStart + index,
        growable: false,
      ),
      _DatePart.month => List<int>.generate(
        12,
        (index) => index + 1,
        growable: false,
      ),
      _DatePart.day => List<int>.generate(
        _maxDay,
        (index) => index + 1,
        growable: false,
      ),
    };
  }

  int? _valueFor(_DatePart part) {
    return switch (part) {
      _DatePart.year => _year,
      _DatePart.month => _month,
      _DatePart.day => _day,
    };
  }

  void _changePart(_DatePart part, int value) {
    setState(() {
      switch (part) {
        case _DatePart.year:
          _year = value;
        case _DatePart.month:
          _month = value;
        case _DatePart.day:
          _day = value;
      }
      _clampDay();
    });
    _emit();
  }

  void _beginManual(_DatePart part) {
    setState(() {
      _manualPart = part;
      _manualController.text = _valueFor(part)?.toString() ?? '';
      _manualController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _manualController.text.length,
      );
    });
  }

  void _commitManual(_DatePart part) {
    if (_manualPart != part) return;
    if (_manualValueError() != null) {
      _formFieldKey.currentState?.validate();
      return;
    }
    final value = int.parse(_manualController.text.trim());
    setState(() {
      switch (part) {
        case _DatePart.year:
          _year = value;
        case _DatePart.month:
          _month = value;
        case _DatePart.day:
          _day = value;
      }
      _manualPart = null;
      _clampDay();
    });
    _emit();
    _formFieldKey.currentState?.validate();
  }

  String? _manualValueError() {
    final part = _manualPart;
    if (part == null) return null;
    final value = int.tryParse(_manualController.text.trim());
    return switch (part) {
      _DatePart.year
          when value == null ||
              value < widget.yearStart ||
              value > widget.yearEnd =>
        '请输入有效年份',
      _DatePart.month when value == null || value < 1 || value > 12 =>
        '请输入 1-12 的月份',
      _DatePart.day when value == null || value < 1 || value > _maxDay =>
        '请输入有效日期',
      _ => null,
    };
  }

  void _clear() {
    setState(() {
      _year = null;
      _month = null;
      _day = null;
      _manualPart = null;
    });
    _emit();
  }

  void _emit() {
    final value = _formattedValue;
    _formFieldKey.currentState?.didChange(value);
    widget.onChanged(value);
  }

  void _syncFromValue(String? value) {
    if (value == null || !_dateTimeService.isValidLocalDateString(value)) {
      _year = null;
      _month = null;
      _day = null;
      return;
    }
    _year = int.parse(value.substring(0, 4));
    _month = int.parse(value.substring(5, 7));
    _day = int.parse(value.substring(8, 10));
    _clampDay();
  }

  void _clampDay() {
    if (_day != null) {
      _day = math.min(_day!, _maxDay);
    }
  }

  int get _maxDay {
    if (_year == null || _month == null) return 31;
    return DateTime(_year!, _month! + 1, 0).day;
  }

  String? get _formattedValue {
    if (_year == null || _month == null || _day == null) return null;
    return '${_year!.toString().padLeft(4, '0')}-'
        '${_month!.toString().padLeft(2, '0')}-'
        '${_day!.toString().padLeft(2, '0')}';
  }

  String _partName(_DatePart part) => switch (part) {
    _DatePart.year => 'Year',
    _DatePart.month => 'Month',
    _DatePart.day => 'Day',
  };

  String _partLabel(_DatePart part) => switch (part) {
    _DatePart.year => '年',
    _DatePart.month => '月',
    _DatePart.day => '日',
  };
}
