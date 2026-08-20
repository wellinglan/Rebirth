abstract final class RouteNames {
  static const authStartup = 'authStartup';
  static const login = 'login';
  static const register = 'register';
  static const developerLogin = 'developerLogin';
  static const accountBindingRequired = 'accountBindingRequired';
  static const sessionRejected = 'sessionRejected';
  static const fatalMigrationError = 'fatalMigrationError';
  static const home = 'home';
  static const today = 'today';
  static const todayHistory = 'todayHistory';
  static const journal = 'journal';
  static const journalHistory = 'journalHistory';
  static const journalPrompts = 'journalPrompts';
  static const plan = 'plan';
  static const growth = 'growth';
  static const health = 'health';
  static const settings = 'settings';
  static const settingsAccount = 'settingsAccount';
  static const settingsAccountSecurity = 'settingsAccountSecurity';
  static const settingsAiConsent = 'settingsAiConsent';
  static const settingsDeveloperOptions = 'settingsDeveloperOptions';
  static const experiencePreview = 'experiencePreview';
  static const syncCenter = 'syncCenter';
  static const settingsProfile = 'settingsProfile';
  static const personalDataOverview = 'personalDataOverview';
  static const fullPersonalDataExport = 'fullPersonalDataExport';
  static const syncConflicts = 'syncConflicts';
  static const syncConflictDetails = 'syncConflictDetails';
  static const aiCoach = 'aiCoach';
  static const aiCoachWeekly = 'aiCoachWeekly';
  static const aiCoachDaily = 'aiCoachDaily';
  static const aiCoachReport = 'aiCoachReport';
  static const aiReports = 'aiReports';
  static const aiReportsDetail = 'aiReportsDetail';
}

abstract final class RoutePaths {
  static const authStartup = '/auth/startup';
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const developerLogin = '/auth/developer';
  static const accountBindingRequired = '/auth/binding-required';
  static const sessionRejected = '/auth/session-rejected';
  static const fatalMigrationError = '/auth/migration-error';
  static const home = '/home';
  static const today = '/today';
  static const todayHistory = '/today/history';
  static const journal = '/journal';
  static const journalHistory = '/journal/history';
  static const journalPrompts = '/journal/prompts';
  static const plan = '/plan';
  static const growth = '/growth';
  static const health = '/health';
  static const settings = '/settings';
  static const settingsAccount = '/settings/account';
  static const settingsAccountSecurity = '/settings/account/security';
  static const settingsAiConsent = '/settings/ai-data-privacy';
  static const settingsDeveloperOptions = '/settings/developer-options';
  static const experiencePreview =
      '/settings/developer-options/experience-preview';
  static const syncCenter = '/settings/sync-center';
  static const settingsProfile = '/settings/profile';
  static const personalDataOverview = '/personal-data';
  static const fullPersonalDataExport = '/settings/personal-data-export';
  static const syncConflicts = '/settings/sync-conflicts';
  static const aiCoach = '/ai-coach';
  static const aiCoachWeekly = '/ai-coach/weekly';
  static const aiReports = '/ai-reports';

  static String aiReportsDetail(String reportId) {
    return '$aiReports/${Uri.encodeComponent(reportId)}';
  }

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

  static String syncConflictsForModule(String moduleId) {
    return Uri(
      path: syncConflicts,
      queryParameters: {'module': moduleId},
    ).toString();
  }
}
