abstract final class RouteNames {
  static const home = 'home';
  static const today = 'today';
  static const todayHistory = 'todayHistory';
  static const journal = 'journal';
  static const plan = 'plan';
  static const growth = 'growth';
  static const health = 'health';
  static const settings = 'settings';
  static const settingsProfile = 'settingsProfile';
  static const aiCoach = 'aiCoach';
  static const aiCoachReport = 'aiCoachReport';
}

abstract final class RoutePaths {
  static const home = '/home';
  static const today = '/today';
  static const todayHistory = '/today/history';
  static const journal = '/journal';
  static const plan = '/plan';
  static const growth = '/growth';
  static const health = '/health';
  static const settings = '/settings';
  static const settingsProfile = '/settings/profile';
  static const aiCoach = '/ai-coach';

  static String aiCoachReport(String reportId) {
    return '$aiCoach/reports/${Uri.encodeComponent(reportId)}';
  }
}
