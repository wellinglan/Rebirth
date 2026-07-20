import 'package:go_router/go_router.dart';

import '../../features/ai_coach/presentation/ai_coach_page.dart';
import '../../features/ai_coach/presentation/ai_daily_insight_page.dart';
import '../../features/ai_coach/presentation/ai_report_detail_page.dart';
import '../../features/growth/presentation/growth_page.dart';
import '../../features/health/presentation/health_page.dart';
import '../../features/journal/presentation/journal_page.dart';
import '../../features/plan/presentation/plan_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/today/presentation/today_page.dart';
import '../../features/today/presentation/today_history_page.dart';
import '../app/home_shell.dart';
import 'route_names.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: RoutePaths.today,
  routes: [
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
                  builder: (context, state) => const TodayHistoryPage(),
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
              builder: (context, state) => const JournalPage(),
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
      path: RoutePaths.aiCoach,
      name: RouteNames.aiCoach,
      builder: (context, state) => const AiCoachPage(),
      routes: [
        GoRoute(
          path: 'daily/:targetDate',
          name: RouteNames.aiCoachDaily,
          builder: (context, state) => AiDailyInsightPage(
            targetDate: state.pathParameters['targetDate'] ?? '',
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
      ],
    ),
  ],
);
