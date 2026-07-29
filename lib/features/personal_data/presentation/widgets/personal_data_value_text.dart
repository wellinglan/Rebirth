import 'package:flutter/material.dart';

import '../../domain/personal_data_value.dart';

String formatPersonalDataValue(PersonalDataValue value, {String? unit}) {
  final formatted = switch (value) {
    PersonalDataTextValue(:final value) => value,
    PersonalDataIntegerValue(:final value) => value.toString(),
    PersonalDataDecimalValue(:final value) => _formatNumber(value),
    PersonalDataBooleanValue(:final value) => value ? '是' : '否',
    PersonalDataDurationValue(:final minutes) => _formatDuration(minutes),
    PersonalDataCountValue(:final value) => value.toString(),
    PersonalDataScoreValue(:final value, :final maximum) =>
      '${_formatNumber(value)} / ${_formatNumber(maximum)}',
    PersonalDataDateValue(:final value) => value,
    PersonalDataDateTimeValue(:final value) => _formatDateTime(value),
    PersonalDataPercentageValue(:final value) => '${_formatNumber(value)}%',
    PersonalDataCategoricalValue(:final value) => _formatCategory(value),
    PersonalDataPresenceValue(:final isPresent) => isPresent ? '是' : '否',
  };
  return unit == null || unit.trim().isEmpty ? formatted : '$formatted $unit';
}

class PersonalDataValueText extends StatelessWidget {
  const PersonalDataValueText({
    required this.value,
    this.unit,
    this.style,
    super.key,
  });

  final PersonalDataValue value;
  final String? unit;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatPersonalDataValue(value, unit: unit),
      style: style,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}

String _formatNumber(num value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}

String _formatCategory(String value) => switch (value) {
  'draft' => '草稿',
  'completed' => '已完成',
  'missing' => '未记录',
  _ => value,
};

String _formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  if (hours == 0) return '$remaining 分钟';
  if (remaining == 0) return '$hours 小时';
  return '$hours 小时 $remaining 分钟';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
