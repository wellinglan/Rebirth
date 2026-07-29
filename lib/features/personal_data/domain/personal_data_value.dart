sealed class PersonalDataValue {
  const PersonalDataValue();
}

final class PersonalDataTextValue extends PersonalDataValue {
  PersonalDataTextValue(
    String value, {
    this.isSummary = false,
    this.maxLength = 120,
  }) : value = _validateText(value, maxLength);

  final String value;
  final bool isSummary;
  final int maxLength;
}

final class PersonalDataIntegerValue extends PersonalDataValue {
  const PersonalDataIntegerValue(this.value);

  final int value;
}

final class PersonalDataDecimalValue extends PersonalDataValue {
  PersonalDataDecimalValue(this.value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'Must be finite.');
    }
  }

  final double value;
}

final class PersonalDataBooleanValue extends PersonalDataValue {
  const PersonalDataBooleanValue(this.value);

  final bool value;
}

final class PersonalDataDurationValue extends PersonalDataValue {
  PersonalDataDurationValue({required this.minutes}) {
    if (minutes < 0) {
      throw ArgumentError.value(minutes, 'minutes', 'Must be non-negative.');
    }
  }

  final int minutes;
}

final class PersonalDataCountValue extends PersonalDataValue {
  PersonalDataCountValue(this.value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'Must be non-negative.');
    }
  }

  final int value;
}

final class PersonalDataScoreValue extends PersonalDataValue {
  PersonalDataScoreValue({
    required this.value,
    required this.minimum,
    required this.maximum,
  }) {
    if (!value.isFinite ||
        !minimum.isFinite ||
        !maximum.isFinite ||
        minimum >= maximum ||
        value < minimum ||
        value > maximum) {
      throw ArgumentError('Score must be finite and within its valid range.');
    }
  }

  final double value;
  final double minimum;
  final double maximum;
}

final class PersonalDataDateValue extends PersonalDataValue {
  PersonalDataDateValue(String value) : value = _validateDate(value);

  final String value;
}

final class PersonalDataDateTimeValue extends PersonalDataValue {
  PersonalDataDateTimeValue(DateTime value)
    : value = _requireUtc(value, 'value');

  final DateTime value;
}

final class PersonalDataPercentageValue extends PersonalDataValue {
  PersonalDataPercentageValue(this.value) {
    if (!value.isFinite || value < 0 || value > 100) {
      throw ArgumentError.value(value, 'value', 'Must be between 0 and 100.');
    }
  }

  final double value;
}

final class PersonalDataCategoricalValue extends PersonalDataValue {
  PersonalDataCategoricalValue(String value) : value = _validateCategory(value);

  final String value;
}

final class PersonalDataPresenceValue extends PersonalDataValue {
  const PersonalDataPresenceValue(this.isPresent);

  final bool isPresent;
}

String _validateText(String value, int maxLength) {
  if (maxLength <= 0) {
    throw ArgumentError.value(maxLength, 'maxLength', 'Must be positive.');
  }
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > maxLength) {
    throw ArgumentError.value(
      value,
      'value',
      'Text must be non-empty and no longer than $maxLength characters.',
    );
  }
  return normalized;
}

String _validateCategory(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 64) {
    throw ArgumentError.value(
      value,
      'value',
      'Category must be non-empty and no longer than 64 characters.',
    );
  }
  return normalized;
}

String _validateDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw ArgumentError.value(value, 'value', 'Must use YYYY-MM-DD.');
  }
  final year = int.parse(value.substring(0, 4));
  final month = int.parse(value.substring(5, 7));
  final day = int.parse(value.substring(8, 10));
  final parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    throw ArgumentError.value(value, 'value', 'Must be a valid date.');
  }
  return value;
}

DateTime _requireUtc(DateTime value, String name) {
  if (!value.isUtc) {
    throw ArgumentError.value(value, name, 'Must be UTC.');
  }
  return value;
}
