import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/domain/app_auth_state.dart';
import '../../features/account/presentation/app_auth_controller.dart';
import '../../features/account/presentation/auth_gate_status_pages.dart';
import '../../features/account/presentation/login_page.dart';
import '../../features/ai_coach/presentation/ai_coach_page.dart';
import '../../features/ai_coach/presentation/ai_daily_insight_page.dart';
import '../../features/ai_coach/presentation/ai_report_detail_page.dart';
import '../../features/ai_coach/domain/ai_data_scope.dart';
import '../../features/growth/presentation/growth_page.dart';
import '../../features/health/presentation/health_page.dart';
import '../../features/journal/presentation/journal_page.dart';
import '../../features/plan/presentation/plan_page.dart';
import '../../features/personal_data/presentation/personal_data_overview_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/sync/presentation/sync_conflict_detail_page.dart';
import '../../features/sync/presentation/sync_conflict_list_page.dart';
import '../../features/today/presentation/today_page.dart';
import '../../features/today/presentation/today_history_page.dart';
import '../app/home_shell.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRouterRefresh(ref.read(appAuthStateProvider));
  ref.listen<AsyncValue<AppAuthState>>(
    appAuthStateProvider,
    (_, next) => refresh.update(next),
  );
  ref.onDispose(refresh.dispose);
  return _createAppRouter(refresh);
});

GoRouter _createAppRouter(_AuthRouterRefresh refresh) {
  return GoRouter(
    initialLocation: RoutePaths.today,
    refreshListenable: refresh,
    redirect: (context, state) => _authRedirect(refresh.auth, state),
    routes: [
      GoRoute(
        path: RoutePaths.authStartup,
        name: RouteNames.authStartup,
        builder: (context, state) => const AuthStartupPage(),
      ),
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        builder: (context, state) => const LoginPage(),
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
            path: 'profile',
            name: RouteNames.settingsProfile,
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: 'sync-conflicts',
            name: RouteNames.syncConflicts,
            builder: (context, state) => const SyncConflictListPage(),
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

String? _authRedirect(AsyncValue<AppAuthState> auth, GoRouterState state) {
  final currentPath = state.uri.path;
  final target = auth.when(
    loading: () => RoutePaths.authStartup,
    error: (_, _) => RoutePaths.fatalMigrationError,
    data: (value) => switch (value.status) {
      AppAuthStatus.initializing => RoutePaths.authStartup,
      AppAuthStatus.signedOut => RoutePaths.login,
      AppAuthStatus.bindingRequired => RoutePaths.accountBindingRequired,
      AppAuthStatus.sessionRejected => RoutePaths.sessionRejected,
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
      path == RoutePaths.accountBindingRequired ||
      path == RoutePaths.sessionRejected ||
      path == RoutePaths.fatalMigrationError;
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
