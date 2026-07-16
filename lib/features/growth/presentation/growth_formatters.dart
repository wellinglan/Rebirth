import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';

abstract final class GrowthFormatters {
  static const String noData = '暂无数据';

  static String duration(int? minutes) {
    if (minutes == null) {
      return noData;
    }
    if (minutes < 0) {
      throw ArgumentError.value(
        minutes,
        'minutes',
        'Minutes must be non-negative.',
      );
    }
    if (minutes < 60) {
      return '$minutes 分钟';
    }

    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0 ? '$hours 小时' : '$hours 小时 $remainder 分钟';
  }

  static String averageDuration(double? minutes) {
    return minutes == null ? noData : duration(minutes.round());
  }

  static String score(double? value) {
    return value == null ? noData : '${value.toStringAsFixed(1)} / 5';
  }

  static String scorePoint(int value) => '$value / 5';

  static String dateRange(String startDate, String endDate) {
    final start = _parse(startDate);
    final end = _parse(endDate);
    if (start.year == end.year) {
      return '${start.month}月${start.day}日 — ${end.month}月${end.day}日';
    }
    return '${start.year}年${start.month}月${start.day}日 — '
        '${end.year}年${end.month}月${end.day}日';
  }

  static String axisDate(String date) {
    final parsed = _parse(date);
    return '${parsed.month}/${parsed.day}';
  }

  static String tooltipDate(String date) {
    final parsed = _parse(date);
    return '${parsed.month}月${parsed.day}日';
  }

  static bool showAxisLabel({
    required int index,
    required int pointCount,
    required GrowthPeriod period,
  }) {
    if (index < 0 || index >= pointCount) {
      return false;
    }
    if (period == GrowthPeriod.sevenDays) {
      return true;
    }
    return index == 0 || index == pointCount - 1 || index % 6 == 0;
  }

  static String minutesAxis(double value) {
    return value.round().toString();
  }

  static String sleepAxis(double value) {
    final hours = value / 60;
    return hours == hours.roundToDouble()
        ? '${hours.round()}h'
        : '${hours.toStringAsFixed(1)}h';
  }

  static ({int year, int month, int day}) _parse(String date) {
    if (!const DateTimeService().isValidLocalDateString(date)) {
      throw FormatException('Invalid local date: $date');
    }
    return (
      year: int.parse(date.substring(0, 4)),
      month: int.parse(date.substring(5, 7)),
      day: int.parse(date.substring(8, 10)),
    );
  }
}
