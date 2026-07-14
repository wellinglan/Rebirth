import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late final TextEditingController _yearController;
  late final TextEditingController _monthController;
  late final TextEditingController _dayController;
  int? _year;
  int? _month;
  int? _day;
  _DatePart? _manualPart;

  @override
  void initState() {
    super.initState();
    _yearController = TextEditingController();
    _monthController = TextEditingController();
    _dayController = TextEditingController();
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
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String?>(
      key: _formFieldKey,
      initialValue: _formattedValue,
      validator: (_) {
        final manualError = _manualValueError();
        if (manualError != null) {
          return manualError;
        }
        final value = _formattedValue;
        if (widget.isRequired && value == null) {
          return '请选择日期';
        }
        return widget.validator?.call(value);
      },
      builder: (field) {
        final errorColor = Theme.of(context).colorScheme.error;
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
                ).textTheme.bodySmall?.copyWith(color: errorColor),
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
        controller: _controllerFor(part),
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9-]'))],
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: _partLabel(part),
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) =>
            _formFieldKey.currentState?.didChange(_formattedValue),
        onFieldSubmitted: (_) => _commitManual(part),
        onTapOutside: (_) => _commitManual(part),
      );
    }

    return GestureDetector(
      key: ValueKey('${widget.fieldId}${_partName(part)}'),
      onDoubleTap: widget.enabled ? () => _beginManual(part) : null,
      child: DropdownButtonFormField<int>(
        key: ValueKey(
          '${widget.fieldId}${_partName(part)}Value${_valueFor(part)}',
        ),
        initialValue: _valueFor(part),
        isExpanded: true,
        decoration: InputDecoration(
          labelText: _partLabel(part),
          border: const OutlineInputBorder(),
        ),
        items: _valuesFor(part)
            .map((value) {
              return DropdownMenuItem<int>(value: value, child: Text('$value'));
            })
            .toList(growable: false),
        onChanged: widget.enabled
            ? (value) {
                if (value != null) {
                  _changePart(part, value);
                }
              }
            : null,
      ),
    );
  }

  Iterable<int> _valuesFor(_DatePart part) {
    return switch (part) {
      _DatePart.year => Iterable<int>.generate(
        widget.yearEnd - widget.yearStart + 1,
        (index) => widget.yearStart + index,
      ),
      _DatePart.month => Iterable<int>.generate(12, (index) => index + 1),
      _DatePart.day => Iterable<int>.generate(_maxDay, (index) => index + 1),
    };
  }

  int? _valueFor(_DatePart part) {
    return switch (part) {
      _DatePart.year => _year,
      _DatePart.month => _month,
      _DatePart.day => _day,
    };
  }

  TextEditingController _controllerFor(_DatePart part) {
    return switch (part) {
      _DatePart.year => _yearController,
      _DatePart.month => _monthController,
      _DatePart.day => _dayController,
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
      _syncControllers();
    });
    _emit();
  }

  void _beginManual(_DatePart part) {
    setState(() {
      _manualPart = part;
      final controller = _controllerFor(part);
      controller.text = _valueFor(part)?.toString() ?? '';
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
    });
  }

  void _commitManual(_DatePart part) {
    if (_manualPart != part) {
      return;
    }
    final error = _manualValueError();
    if (error != null) {
      _formFieldKey.currentState?.validate();
      return;
    }

    final value = int.parse(_controllerFor(part).text.trim());
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
      _syncControllers();
    });
    _emit();
    _formFieldKey.currentState?.validate();
  }

  String? _manualValueError() {
    final part = _manualPart;
    if (part == null) {
      return null;
    }
    final value = int.tryParse(_controllerFor(part).text.trim());
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
      _syncControllers();
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
    } else {
      _year = int.parse(value.substring(0, 4));
      _month = int.parse(value.substring(5, 7));
      _day = int.parse(value.substring(8, 10));
      _clampDay();
    }
    _syncControllers();
  }

  void _syncControllers() {
    _yearController.text = _year?.toString() ?? '';
    _monthController.text = _month?.toString() ?? '';
    _dayController.text = _day?.toString() ?? '';
  }

  void _clampDay() {
    if (_day != null) {
      _day = math.min(_day!, _maxDay);
    }
  }

  int get _maxDay {
    final year = _year;
    final month = _month;
    if (year == null || month == null) {
      return 31;
    }
    return DateTime(year, month + 1, 0).day;
  }

  String? get _formattedValue {
    if (_year == null || _month == null || _day == null) {
      return null;
    }
    return '${_year!.toString().padLeft(4, '0')}-'
        '${_month!.toString().padLeft(2, '0')}-'
        '${_day!.toString().padLeft(2, '0')}';
  }

  String _partName(_DatePart part) {
    return switch (part) {
      _DatePart.year => 'Year',
      _DatePart.month => 'Month',
      _DatePart.day => 'Day',
    };
  }

  String _partLabel(_DatePart part) {
    return switch (part) {
      _DatePart.year => '年',
      _DatePart.month => '月',
      _DatePart.day => '日',
    };
  }
}
