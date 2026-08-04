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
    expect(RoutePaths.journalForDate('2026-07-16'), '/journal?date=2026-07-16');
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
    expect(RoutePaths.settingsAccountSecurity, '/settings/account/security');
    expect(RoutePaths.settingsAiConsent, '/settings/ai-data-privacy');
  });

  test('public authentication routes contain no credential parameters', () {
    expect(RoutePaths.login, '/auth/login');
    expect(RoutePaths.register, '/auth/register');
    expect(RoutePaths.developerLogin, '/auth/developer');
    for (final path in [
      RoutePaths.login,
      RoutePaths.register,
      RoutePaths.developerLogin,
    ]) {
      expect(Uri.parse(path).query, isEmpty);
    }
  });

  test('Daily refresh route preserves sorted original scopes', () {
    final location = RoutePaths.aiCoachDaily(
      '2026-07-16',
      scopes: ['journal_reflections', 'today_metrics'],
    );
    final uri = Uri.parse(location);

    expect(uri.path, '/ai-coach/daily/2026-07-16');
    expect(uri.queryParameters['scopes'], 'journal_reflections,today_metrics');
  });

  test('sync conflict routes preserve an encoded opaque conflict id', () {
    expect(RoutePaths.syncConflicts, '/settings/sync-conflicts');
    final location = RoutePaths.syncConflictDetails('conflict id/alpha');

    expect(location, isNot(contains(' ')));
    expect(Uri.parse(location).pathSegments, [
      'settings',
      'sync-conflicts',
      'conflict id/alpha',
    ]);
  });

  test('AI report library route preserves an encoded opaque report id', () {
    expect(RoutePaths.aiReports, '/ai-reports');
    final location = RoutePaths.aiReportsDetail('report id/alpha');

    expect(location, isNot(contains(' ')));
    expect(Uri.parse(location).pathSegments, ['ai-reports', 'report id/alpha']);
  });
}
