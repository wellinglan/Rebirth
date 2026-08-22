import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/app/rebirth_app.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/account/domain/app_auth_state.dart';
import 'package:rebirth/features/account/presentation/app_auth_controller.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';

import 'features/ai_coach/ai_coach_test_support.dart';

void main() {
  testWidgets('renders Today state and switches destinations', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final bootstrap = await database.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          dateTimeServiceProvider.overrideWithValue(
            DateTimeService(now: () => DateTime(2026, 7, 10, 9)),
          ),
          appAuthStateProvider.overrideWithValue(
            AsyncData(
              AppAuthState(
                status: AppAuthStatus.authenticated,
                localUserId: bootstrap.activeUserId,
                cloudUserId: 'widget-user',
              ),
            ),
          ),
          aiGenerationGatewayProvider.overrideWithValue(
            FakeAiGenerationGateway(),
          ),
        ],
        child: const RebirthApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('productionHomePage')), findsOneWidget);
    expect(find.text('本地固定寄语 · 不调用 AI'), findsOneWidget);
    final homeContext = tester.element(
      find.byKey(const ValueKey('productionHomePage')),
    );
    GoRouter.of(homeContext).go(RoutePaths.today);
    await tester.pumpAndSettle();

    expect(find.text('2026-07-10'), findsOneWidget);
    expect(find.byKey(const ValueKey('todayEmptyState')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('openTodayHistoryButton')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('openTodayHistoryButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('todayHistoryPage')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('todayHistoryEmptyState')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('todayHistoryBackButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('saveTodayButton')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.auto_stories_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.auto_stories), findsOneWidget);
    expect(find.byKey(const ValueKey('saveJournalButton')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.account_tree_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.account_tree), findsOneWidget);
    expect(find.byKey(const ValueKey('planEmptyState')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.insights), findsOneWidget);
    expect(find.text('看见缓慢而真实的变化。'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.monitor_heart_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.monitor_heart), findsOneWidget);
    expect(find.byKey(const ValueKey('healthDataState')), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('homeNavigationBar')),
        matching: find.byIcon(Icons.auto_awesome),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('aiChatPage')), findsOneWidget);

    final aiContext = tester.element(find.byKey(const ValueKey('aiChatPage')));
    final router = GoRouter.of(aiContext);
    router.go('${RoutePaths.aiCoachChat}?thread=missing-local-thread');
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, RoutePaths.aiCoach);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['thread'],
      'missing-local-thread',
    );
    expect(find.byKey(const ValueKey('aiChatPage')), findsOneWidget);
  });
}
