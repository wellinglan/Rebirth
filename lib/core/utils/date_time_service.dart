import 'package:flutter_riverpod/flutter_riverpod.dart';

final dateTimeServiceProvider = Provider<DateTimeService>(
  (ref) => const DateTimeService(),
);

class DateTimeService {
  const DateTimeService();

  static final RegExp _localDatePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  int currentUtcMillisecondsSinceEpoch() {
    return DateTime.now().toUtc().millisecondsSinceEpoch;
  }

  String currentLocalDateString() {
    return formatLocalDate(DateTime.now());
  }

  String formatLocalDate(DateTime dateTime) {
    final localDateTime = dateTime.toLocal();
    return '${localDateTime.year.toString().padLeft(4, '0')}-'
        '${localDateTime.month.toString().padLeft(2, '0')}-'
        '${localDateTime.day.toString().padLeft(2, '0')}';
  }

  int currentTimezoneOffsetMinutes() {
    return DateTime.now().timeZoneOffset.inMinutes;
  }

  List<String> recentLocalDateRange(int days, {DateTime? endingAt}) {
    if (days <= 0) {
      return const <String>[];
    }

    final endDate = (endingAt ?? DateTime.now()).toLocal();
    final startDate = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    ).subtract(Duration(days: days - 1));

    return List<String>.generate(
      days,
      (index) => formatLocalDate(startDate.add(Duration(days: index))),
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
