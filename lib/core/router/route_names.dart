abstract final class RouteNames {
  static const authStartup = 'authStartup';
  static const login = 'login';
  static const accountBindingRequired = 'accountBindingRequired';
  static const sessionRejected = 'sessionRejected';
  static const fatalMigrationError = 'fatalMigrationError';
  static const home = 'home';
  static const today = 'today';
  static const todayHistory = 'todayHistory';
  static const journal = 'journal';
  static const plan = 'plan';
  static const growth = 'growth';
  static const health = 'health';
  static const settings = 'settings';
  static const settingsProfile = 'settingsProfile';
  static const syncConflicts = 'syncConflicts';
  static const syncConflictDetails = 'syncConflictDetails';
  static const aiCoach = 'aiCoach';
  static const aiCoachDaily = 'aiCoachDaily';
  static const aiCoachReport = 'aiCoachReport';
}

abstract final class RoutePaths {
  static const authStartup = '/auth/startup';
  static const login = '/login';
  static const accountBindingRequired = '/auth/binding-required';
  static const sessionRejected = '/auth/session-rejected';
  static const fatalMigrationError = '/auth/migration-error';
  static const home = '/home';
  static const today = '/today';
  static const todayHistory = '/today/history';
  static const journal = '/journal';
  static const plan = '/plan';
  static const growth = '/growth';
  static const health = '/health';
  static const settings = '/settings';
  static const settingsProfile = '/settings/profile';
  static const syncConflicts = '/settings/sync-conflicts';
  static const aiCoach = '/ai-coach';

  static String todayHistoryForDate(String date) {
    return Uri(path: todayHistory, queryParameters: {'date': date}).toString();
  }

  static String journalForDate(String date) {
    return Uri(path: journal, queryParameters: {'date': date}).toString();
  }

  static String aiCoachDaily(
    String targetDate, {
    Iterable<String> scopes = const [],
  }) {
    final sortedScopes = scopes.toSet().toList()..sort();
    return Uri(
      path: '$aiCoach/daily/${Uri.encodeComponent(targetDate)}',
      queryParameters: sortedScopes.isEmpty
          ? null
          : {'scopes': sortedScopes.join(',')},
    ).toString();
  }

  static String aiCoachReport(String reportId) {
    return '$aiCoach/reports/${Uri.encodeComponent(reportId)}';
  }

  static String syncConflictDetails(String conflictId) {
    return '$syncConflicts/${Uri.encodeComponent(conflictId)}';
  }
}
