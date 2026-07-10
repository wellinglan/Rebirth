class DateTimeService {
  const DateTimeService({this.now = DateTime.now});

  static final RegExp _localDatePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  final DateTime Function() now;

  int currentUtcMillisecondsSinceEpoch() {
    return now().toUtc().millisecondsSinceEpoch;
  }

  String currentLocalDateString() {
    return formatLocalDate(now());
  }

  DateTimeSnapshot currentSnapshot() {
    final currentDateTime = now();

    return DateTimeSnapshot(
      now: currentDateTime,
      utcMilliseconds: currentDateTime.toUtc().millisecondsSinceEpoch,
      localDateString: formatLocalDate(currentDateTime),
      timezoneOffsetMinutes: currentDateTime.timeZoneOffset.inMinutes,
    );
  }

  String formatLocalDate(DateTime dateTime) {
    final localDateTime = dateTime.toLocal();
    return '${localDateTime.year.toString().padLeft(4, '0')}-'
        '${localDateTime.month.toString().padLeft(2, '0')}-'
        '${localDateTime.day.toString().padLeft(2, '0')}';
  }

  int currentTimezoneOffsetMinutes() {
    return now().timeZoneOffset.inMinutes;
  }

  List<String> recentLocalDateRange(int days, {DateTime? endingAt}) {
    if (days <= 0) {
      return const <String>[];
    }

    final endDate = (endingAt ?? now()).toLocal();
    final startDate = DateTime(
      endDate.year,
      endDate.month,
      endDate.day - days + 1,
    );

    return List<String>.generate(
      days,
      (index) => formatLocalDate(
        DateTime(startDate.year, startDate.month, startDate.day + index),
      ),
    );
  }

  bool isValidLocalDateString(String value) {
    if (!_localDatePattern.hasMatch(value)) {
      return false;
    }

    final year = int.parse(value.substring(0, 4));
    final month = int.parse(value.substring(5, 7));
    final day = int.parse(value.substring(8, 10));
    final parsed = DateTime(year, month, day);

    return parsed.year == year && parsed.month == month && parsed.day == day;
  }
}

class DateTimeSnapshot {
  const DateTimeSnapshot({
    required this.now,
    required this.utcMilliseconds,
    required this.localDateString,
    required this.timezoneOffsetMinutes,
  });

  final DateTime now;
  final int utcMilliseconds;
  final String localDateString;
  final int timezoneOffsetMinutes;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DateTimeSnapshot &&
            now == other.now &&
            utcMilliseconds == other.utcMilliseconds &&
            localDateString == other.localDateString &&
            timezoneOffsetMinutes == other.timezoneOffsetMinutes;
  }

  @override
  int get hashCode => Object.hash(
        now,
        utcMilliseconds,
        localDateString,
        timezoneOffsetMinutes,
      );
}
