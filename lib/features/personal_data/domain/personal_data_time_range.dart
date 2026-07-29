final class PersonalDataLocalTimeContext {
  const PersonalDataLocalTimeContext({
    required this.timezoneOffsetMinutes,
    this.timezoneId,
  }) : assert(timezoneOffsetMinutes >= -840 && timezoneOffsetMinutes <= 840);

  final int timezoneOffsetMinutes;
  final String? timezoneId;
}

final class PersonalDataTimeRange {
  PersonalDataTimeRange({
    required DateTime startInclusiveUtc,
    required DateTime endExclusiveUtc,
    required this.startLocalDate,
    required this.endLocalDateInclusive,
  }) : startInclusiveUtc = _requireUtc(startInclusiveUtc, 'startInclusiveUtc'),
       endExclusiveUtc = _requireUtc(endExclusiveUtc, 'endExclusiveUtc') {
    if (!this.startInclusiveUtc.isBefore(this.endExclusiveUtc)) {
      throw ArgumentError('Time range must be non-empty and increasing.');
    }
    _parseLocalDate(startLocalDate);
    _parseLocalDate(endLocalDateInclusive);
    if (startLocalDate.compareTo(endLocalDateInclusive) > 0) {
      throw ArgumentError('Local date range must be increasing.');
    }
  }

  factory PersonalDataTimeRange.forLocalDate({
    required String localDate,
    required PersonalDataLocalTimeContext timeContext,
  }) {
    final parts = _parseLocalDate(localDate);
    final start = DateTime.utc(
      parts.$1,
      parts.$2,
      parts.$3,
    ).subtract(Duration(minutes: timeContext.timezoneOffsetMinutes));
    return PersonalDataTimeRange(
      startInclusiveUtc: start,
      endExclusiveUtc: start.add(const Duration(days: 1)),
      startLocalDate: localDate,
      endLocalDateInclusive: localDate,
    );
  }

  factory PersonalDataTimeRange.forSystemLocalDate(String localDate) {
    final parts = _parseLocalDate(localDate);
    final startLocal = DateTime(parts.$1, parts.$2, parts.$3);
    final endLocal = DateTime(parts.$1, parts.$2, parts.$3 + 1);
    return PersonalDataTimeRange(
      startInclusiveUtc: startLocal.toUtc(),
      endExclusiveUtc: endLocal.toUtc(),
      startLocalDate: localDate,
      endLocalDateInclusive: localDate,
    );
  }

  factory PersonalDataTimeRange.forSystemLocalDateRange({
    required String startLocalDate,
    required String endLocalDateInclusive,
  }) {
    final startParts = _parseLocalDate(startLocalDate);
    final endParts = _parseLocalDate(endLocalDateInclusive);
    if (startLocalDate.compareTo(endLocalDateInclusive) > 0) {
      throw ArgumentError('Local date range must be increasing.');
    }
    final startLocal = DateTime(startParts.$1, startParts.$2, startParts.$3);
    final endExclusiveLocal = DateTime(
      endParts.$1,
      endParts.$2,
      endParts.$3 + 1,
    );
    return PersonalDataTimeRange(
      startInclusiveUtc: startLocal.toUtc(),
      endExclusiveUtc: endExclusiveLocal.toUtc(),
      startLocalDate: startLocalDate,
      endLocalDateInclusive: endLocalDateInclusive,
    );
  }

  final DateTime startInclusiveUtc;
  final DateTime endExclusiveUtc;
  final String startLocalDate;
  final String endLocalDateInclusive;

  bool containsUtc(DateTime value) {
    final utc = value.toUtc();
    return !utc.isBefore(startInclusiveUtc) && utc.isBefore(endExclusiveUtc);
  }
}

(int, int, int) _parseLocalDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw ArgumentError.value(value, 'localDate', 'Must use YYYY-MM-DD.');
  }
  final year = int.parse(value.substring(0, 4));
  final month = int.parse(value.substring(5, 7));
  final day = int.parse(value.substring(8, 10));
  final parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    throw ArgumentError.value(value, 'localDate', 'Must be a valid date.');
  }
  return (year, month, day);
}

DateTime _requireUtc(DateTime value, String name) {
  if (!value.isUtc) {
    throw ArgumentError.value(value, name, 'Must be UTC.');
  }
  return value;
}
