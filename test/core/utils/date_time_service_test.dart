import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/utils/date_time_service.dart';

void main() {
  const service = DateTimeService();

  test('formats DateTime as YYYY-MM-DD', () {
    expect(
      service.formatLocalDate(DateTime(2026, 7, 10, 23, 59)),
      '2026-07-10',
    );
    expect(
      service.currentLocalDateString(),
      matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
    );
  });

  test('returns UTC milliseconds as an integer', () {
    final milliseconds = service.currentUtcMillisecondsSinceEpoch();

    expect(milliseconds, isA<int>());
    expect(milliseconds, greaterThan(0));
  });

  test('returns timezone offset matching DateTime.now()', () {
    expect(
      service.currentTimezoneOffsetMinutes(),
      DateTime.now().timeZoneOffset.inMinutes,
    );
  });

  test('generates a recent 7 day local date range', () {
    final range = service.recentLocalDateRange(
      7,
      endingAt: DateTime(2026, 7, 10, 18),
    );

    expect(range, hasLength(7));
    expect(range.first, '2026-07-04');
    expect(range.last, '2026-07-10');
  });

  test('recognizes invalid YYYY-MM-DD strings', () {
    expect(service.isValidLocalDateString('2026-07-10'), isTrue);
    expect(service.isValidLocalDateString('2026-2-10'), isFalse);
    expect(service.isValidLocalDateString('2026-02-30'), isFalse);
    expect(service.isValidLocalDateString('2026-13-01'), isFalse);
    expect(service.isValidLocalDateString('not-a-date'), isFalse);
  });
}
