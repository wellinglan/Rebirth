import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/utils/date_time_service.dart';

void main() {
  const dateTimeService = DateTimeService();

  test('builds Today history URL for an exact date', () {
    expect(
      RoutePaths.todayHistoryForDate('2026-07-16'),
      '/today/history?date=2026-07-16',
    );
  });

  test('builds Journal URL for an exact date', () {
    expect(
      RoutePaths.journalForDate('2026-07-16'),
      '/journal?date=2026-07-16',
    );
  });

  test('date query values are URL encoded', () {
    final location = RoutePaths.todayHistoryForDate('2026-07-16 invalid');

    expect(location, isNot(contains(' ')));
    expect(Uri.parse(location).queryParameters['date'], '2026-07-16 invalid');
  });

  test('exact-date routes use DateTimeService validation', () {
    expect(dateTimeService.isValidLocalDateString('2026-07-16'), isTrue);
    expect(dateTimeService.isValidLocalDateString('2026-02-30'), isFalse);
  });

  test('existing route locations remain available without a date', () {
    expect(RoutePaths.todayHistory, '/today/history');
    expect(RoutePaths.journal, '/journal');
  });
}
