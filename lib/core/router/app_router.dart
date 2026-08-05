import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../config/app_config_provider.dart';
import '../../features/account/domain/app_auth_state.dart';
import '../../features/account/presentation/app_auth_controller.dart';
import '../../features/account/presentation/auth_gate_status_pages.dart';
import '../../features/account/presentation/developer_login_page.dart';
import '../../features/account/presentation/login_page.dart';
import '../../features/account/presentation/register_page.dart';
import '../../features/ai_coach/presentation/ai_coach_page.dart';
import '../../features/ai_coach/presentation/ai_daily_insight_page.dart';
import '../../features/ai_coach/presentation/ai_report_detail_page.dart';
import '../../features/ai_coach/domain/ai_data_scope.dart';
import '../../features/ai_reports/presentation/ai_report_library_page.dart';
import '../../features/growth/presentation/growth_page.dart';
import '../../features/health/presentation/health_page.dart';
import '../../features/journal/presentation/journal_page.dart';
import '../../features/journal/presentation/journal_prompt_management_page.dart';
import '../../features/plan/presentation/plan_page.dart';
import '../../features/personal_data/presentation/personal_data_overview_page.dart';
import '../../features/personal_data_export/presentation/full_personal_data_export_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/settings/presentation/account_details_page.dart';
import '../../features/settings/presentation/account_security_page.dart';
import '../../features/settings/presentation/ai_consent_settings_page.dart';
import '../../features/settings/presentation/developer_options_page.dart';
import '../../features/sync/presentation/sync_center_page.dart';
import '../../features/sync/presentation/sync_conflict_detail_page.dart';
import '../../features/sync/presentation/sync_conflict_list_page.dart';
import '../../features/today/presentation/today_page.dart';
import '../../features/today/presentation/today_history_page.dart';
import '../app/home_shell.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final config = ref.watch(appConfigProvider);
  final refresh = _AuthRouterRefresh(ref.read(appAuthStateProvider));
  ref.listen<AsyncValue<AppAuthState>>(
    appAuthStateProvider,
    (_, next) => refresh.update(next),
  );
  ref.onDispose(refresh.dispose);
  return _createAppRouter(refresh, config);
});

GoRouter _createAppRouter(_AuthRouterRefresh refresh, AppConfig config) {
  return GoRouter(
    initialLocation: RoutePaths.today,
    refreshListenable: refresh,
    redirect: (context, state) => _authRedirect(refresh.auth, state, config),
    routes: [
      GoRoute(
        path: RoutePaths.authStartup,
        name: RouteNames.authStartup,
        builder: (context, state) => const AuthStartupPage(),
      ),
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        builder: (context, state) => const PublicLoginPage(),
      ),
      GoRoute(
        path: RoutePaths.register,
        name: RouteNames.register,
        builder: (context, state) => const PublicRegisterPage(),
      ),
      if (config.enableDevLogin)
        GoRoute(
          path: RoutePaths.developerLogin,
          name: RouteNames.developerLogin,
          builder: (context, state) => const DeveloperLoginPage(),
        ),
      GoRoute(
        path: RoutePaths.accountBindingRequired,
        name: RouteNames.accountBindingRequired,
        builder: (context, state) => const AccountBindingRequiredPage(),
      ),
      GoRoute(
        path: RoutePaths.sessionRejected,
        name: RouteNames.sessionRejected,
        builder: (context, state) => const SessionRejectedPage(),
      ),
      GoRoute(
        path: RoutePaths.fatalMigrationError,
        name: RouteNames.fatalMigrationError,
        builder: (context, state) => const FatalMigrationErrorPage(),
      ),
      GoRoute(path: '/', redirect: (_, _) => RoutePaths.today),
      GoRoute(
        path: RoutePaths.home,
        name: RouteNames.home,
        redirect: (_, _) => RoutePaths.today,
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.today,
                name: RouteNames.today,
                builder: (context, state) => const TodayPage(),
                routes: [
                  GoRoute(
                    path: 'history',
                    name: RouteNames.todayHistory,
                    builder: (context, state) => TodayHistoryPage(
                      targetDate: state.uri.queryParameters['date'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.journal,
                name: RouteNames.journal,
                builder: (context, state) =>
                    JournalPage(targetDate: state.uri.queryParameters['date']),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.plan,
                name: RouteNames.plan,
                builder: (context, state) => const PlanPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.health,
                name: RouteNames.health,
                builder: (context, state) => const HealthPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.growth,
                name: RouteNames.growth,
                builder: (context, state) => const GrowthPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.personalDataOverview,
        name: RouteNames.personalDataOverview,
        builder: (context, state) => const PersonalDataOverviewPage(),
      ),
      GoRoute(
        path: RoutePaths.journalPrompts,
        name: RouteNames.journalPrompts,
        builder: (context, state) => const JournalPromptManagementPage(),
      ),
      GoRoute(
        path: RoutePaths.aiCoach,
        name: RouteNames.aiCoach,
        builder: (context, state) => const AiCoachPage(),
        routes: [
          GoRoute(
            path: 'daily/:targetDate',
            name: RouteNames.aiCoachDaily,
            builder: (context, state) => AiDailyInsightPage(
              targetDate: state.pathParameters['targetDate'] ?? '',
              initialScopes: _dailyScopesFrom(
                state.uri.queryParameters['scopes'],
              ),
            ),
          ),
          GoRoute(
            path: 'reports/:reportId',
            name: RouteNames.aiCoachReport,
            redirect: (context, state) => RoutePaths.aiReportsDetail(
              state.pathParameters['reportId'] ?? '',
            ),
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.aiReports,
        name: RouteNames.aiReports,
        builder: (context, state) => const AiReportLibraryPage(),
        routes: [
          GoRoute(
            path: ':reportId',
            name: RouteNames.aiReportsDetail,
            builder: (context, state) => AiReportDetailPage(
              reportId: state.pathParameters['reportId'] ?? '',
            ),
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.settings,
        name: RouteNames.settings,
        builder: (context, state) => const SettingsPage(),
        routes: [
          GoRoute(
            path: 'account',
            name: RouteNames.settingsAccount,
            builder: (context, state) => const AccountDetailsPage(),
            routes: [
              GoRoute(
                path: 'security',
                name: RouteNames.settingsAccountSecurity,
                builder: (context, state) => const AccountSecurityPage(),
              ),
            ],
          ),
          GoRoute(
            path: 'ai-data-privacy',
            name: RouteNames.settingsAiConsent,
            builder: (context, state) => const AiConsentSettingsPage(),
          ),
          if (config.enableDevLogin)
            GoRoute(
              path: 'developer-options',
              name: RouteNames.settingsDeveloperOptions,
              builder: (context, state) => const DeveloperOptionsPage(),
            ),
          GoRoute(
            path: 'sync-center',
            name: RouteNames.syncCenter,
            builder: (context, state) => const SyncCenterPage(),
          ),
          GoRoute(
            path: 'profile',
            name: RouteNames.settingsProfile,
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: 'personal-data-export',
            name: RouteNames.fullPersonalDataExport,
            builder: (context, state) => const FullPersonalDataExportPage(),
          ),
          GoRoute(
            path: 'sync-conflicts',
            name: RouteNames.syncConflicts,
            builder: (context, state) => SyncConflictListPage(
              initialModuleId: state.uri.queryParameters['module'],
            ),
            routes: [
              GoRoute(
                path: ':conflictId',
                name: RouteNames.syncConflictDetails,
                builder: (context, state) => SyncConflictDetailPage(
                  conflictId: state.pathParameters['conflictId'] ?? '',
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

String? _authRedirect(
  AsyncValue<AppAuthState> auth,
  GoRouterState state,
  AppConfig config,
) {
  final currentPath = state.uri.path;
  final devRouteDenied =
      !config.enableDevLogin &&
      (currentPath == RoutePaths.developerLogin ||
          currentPath == RoutePaths.settingsDeveloperOptions);
  if (devRouteDenied) {
    return auth.value?.canAccessBusiness == true
        ? RoutePaths.settings
        : RoutePaths.login;
  }
  final target = auth.when(
    loading: () => RoutePaths.authStartup,
    error: (_, _) => RoutePaths.fatalMigrationError,
    data: (value) => switch (value.status) {
      AppAuthStatus.initializing => RoutePaths.authStartup,
      AppAuthStatus.signedOut ||
      AppAuthStatus.submittingLogin ||
      AppAuthStatus.submittingRegister ||
      AppAuthStatus.submittingDeveloperLogin ||
      AppAuthStatus.sessionRejected ||
      AppAuthStatus.refreshOutcomeUnknown =>
        _isPublicAuthPath(currentPath, config) ? null : RoutePaths.login,
      AppAuthStatus.bindingRequired => RoutePaths.accountBindingRequired,
      AppAuthStatus.fatalMigrationError => RoutePaths.fatalMigrationError,
      AppAuthStatus.authenticated || AppAuthStatus.authenticatedOffline =>
        _isAuthGatePath(currentPath) ? RoutePaths.today : null,
    },
  );
  return target == currentPath ? null : target;
}

bool _isAuthGatePath(String path) {
  return path == RoutePaths.authStartup ||
      path == RoutePaths.login ||
      path == RoutePaths.register ||
      path == RoutePaths.developerLogin ||
      path == RoutePaths.accountBindingRequired ||
      path == RoutePaths.sessionRejected ||
      path == RoutePaths.fatalMigrationError;
}

bool _isPublicAuthPath(String path, AppConfig config) {
  return path == RoutePaths.login ||
      path == RoutePaths.register ||
      (config.enableDevLogin && path == RoutePaths.developerLogin);
}

final class _AuthRouterRefresh extends ChangeNotifier {
  _AuthRouterRefresh(this.auth);

  AsyncValue<AppAuthState> auth;

  void update(AsyncValue<AppAuthState> next) {
    auth = next;
    notifyListeners();
  }
}

Set<AiDataScope> _dailyScopesFrom(String? value) {
  if (value == null || value.trim().isEmpty) return const {};
  final supported = AiDataScope.values.where((scope) => scope.supported);
  return supported
      .where((scope) => value.split(',').contains(scope.contractValue))
      .toSet();
}
