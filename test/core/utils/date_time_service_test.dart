import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/utils/date_time_service.dart';

void main() {
  const service = DateTimeService();
  final fixedNow = DateTime(2026, 7, 10, 23, 59, 58, 321);
  final fixedService = DateTimeService(now: () => fixedNow);

  test('formats DateTime as YYYY-MM-DD', () {
    expect(
      service.formatLocalDate(DateTime(2026, 7, 10, 23, 59)),
      '2026-07-10',
    );
  });

  test('returns a predictable local date with a fixed clock', () {
    expect(fixedService.currentLocalDateString(), '2026-07-10');
  });

  test('returns predictable UTC milliseconds with a fixed clock', () {
    final milliseconds = fixedService.currentUtcMillisecondsSinceEpoch();

    expect(milliseconds, isA<int>());
    expect(milliseconds, fixedNow.toUtc().millisecondsSinceEpoch);
  });

  test('returns timezone offset matching the clock', () {
    expect(
      fixedService.currentTimezoneOffsetMinutes(),
      fixedNow.timeZoneOffset.inMinutes,
    );
  });

  test('currentSnapshot derives all fields from one clock read', () {
    var clockReads = 0;
    final snapshotService = DateTimeService(
      now: () {
        clockReads += 1;
        return fixedNow;
      },
    );

    final snapshot = snapshotService.currentSnapshot();

    expect(clockReads, 1);
    expect(snapshot.now, same(fixedNow));
    expect(snapshot.utcMilliseconds, fixedNow.toUtc().millisecondsSinceEpoch);
    expect(snapshot.localDateString, '2026-07-10');
    expect(
      snapshot.timezoneOffsetMinutes,
      fixedNow.timeZoneOffset.inMinutes,
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

  test('generates a one day local date range', () {
    expect(
      service.recentLocalDateRange(1, endingAt: DateTime(2026, 7, 10, 18)),
      <String>['2026-07-10'],
    );
  });

  test('returns an empty range when days is not positive', () {
    expect(service.recentLocalDateRange(0), isEmpty);
    expect(service.recentLocalDateRange(-1), isEmpty);
  });

  test('recognizes invalid YYYY-MM-DD strings', () {
    expect(service.isValidLocalDateString('2026-07-10'), isTrue);
    expect(service.isValidLocalDateString('2026-2-10'), isFalse);
    expect(service.isValidLocalDateString('2026-02-30'), isFalse);
    expect(service.isValidLocalDateString('2026-13-01'), isFalse);
    expect(service.isValidLocalDateString('not-a-date'), isFalse);
  });
}
