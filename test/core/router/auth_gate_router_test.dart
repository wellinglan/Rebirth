import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/app/rebirth_app.dart';
import 'package:rebirth/core/config/app_config.dart';
import 'package:rebirth/core/config/app_config_provider.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/router/app_router.dart';
import 'package:rebirth/features/account/domain/account_boundary.dart';
import 'package:rebirth/features/account/domain/app_auth_state.dart';
import 'package:rebirth/features/account/presentation/app_auth_controller.dart';
import 'package:rebirth/features/account/presentation/legacy_data_resolution_controller.dart';

void main() {
  testWidgets('signed-out access to business routes redirects to login', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appAuthStateProvider.overrideWithValue(
            const AsyncData(AppAuthState.signedOut()),
          ),
        ],
        child: const RebirthApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('loginPage')), findsOneWidget);
    expect(find.byKey(const ValueKey('todayEmptyState')), findsNothing);
  });

  testWidgets('bindingRequired cannot enter business routes', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appAuthStateProvider.overrideWithValue(
            const AsyncData(
              AppAuthState(
                status: AppAuthStatus.bindingRequired,
                unboundProfileCount: 1,
              ),
            ),
          ),
          legacyDataResolutionControllerProvider.overrideWith(
            _FakeLegacyDataResolutionController.new,
          ),
        ],
        child: const RebirthApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('accountBindingRequiredPage')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('todayEmptyState')), findsNothing);
  });

  testWidgets('signed-out public login does not expose endpoint or dev key', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig.test(enableDevLogin: false),
          ),
          appAuthStateProvider.overrideWithValue(
            const AsyncData(AppAuthState.signedOut()),
          ),
        ],
        child: const RebirthApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('publicLoginPage')), findsOneWidget);
    expect(find.text('Development User Key'), findsNothing);
    expect(find.textContaining('Server Base URL'), findsNothing);
    expect(find.byKey(const ValueKey('openRegisterButton')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('openDeveloperLoginButton')),
      findsNothing,
    );
  });

  testWidgets('authenticated account can enter Today', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final bootstrap = await database.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          appAuthStateProvider.overrideWithValue(
            AsyncData(
              AppAuthState(
                status: AppAuthStatus.authenticated,
                localUserId: bootstrap.activeUserId,
                cloudUserId: 'cloud-a',
              ),
            ),
          ),
        ],
        child: const RebirthApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('loginPage')), findsNothing);
    expect(find.byKey(const ValueKey('todayEmptyState')), findsOneWidget);
  });

  testWidgets('signed-out user can navigate between login and register', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig.test(enableDevLogin: false),
          ),
          appAuthStateProvider.overrideWithValue(
            const AsyncData(AppAuthState.signedOut()),
          ),
        ],
        child: const RebirthApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('openRegisterButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('publicRegisterPage')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('publicLoginPage')), findsOneWidget);
  });

  testWidgets('production deep link cannot create developer login widget', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.fromValues(
            environmentValue: 'production',
            serverEndpoint: 'https://api.example.invalid',
            enableDevLoginValue: 'true',
          ),
        ),
        appAuthStateProvider.overrideWithValue(
          const AsyncData(AppAuthState.signedOut()),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    router.go('/auth/developer');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const RebirthApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('publicLoginPage')), findsOneWidget);
    expect(find.byKey(const ValueKey('developerLoginPage')), findsNothing);
    expect(find.text('Development User Key'), findsNothing);
  });

  for (final state in [
    const AppAuthState(
      status: AppAuthStatus.sessionRejected,
      message: '登录状态已失效，请重新登录。',
    ),
    const AppAuthState(
      status: AppAuthStatus.refreshOutcomeUnknown,
      message: '登录状态无法确认，请重新登录。',
    ),
  ]) {
    testWidgets('${state.status.name} returns to public login safely', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig.test(enableDevLogin: false),
            ),
            appAuthStateProvider.overrideWithValue(AsyncData(state)),
          ],
          child: const RebirthApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('publicLoginPage')), findsOneWidget);
      expect(find.text(state.message!), findsOneWidget);
      expect(find.byKey(const ValueKey('todayEmptyState')), findsNothing);
    });
  }
}

final class _FakeLegacyDataResolutionController
    extends LegacyDataResolutionController {
  @override
  Future<LegacyDataResolutionState> build() async {
    return const LegacyDataResolutionState(
      summaries: [
        LegacyLocalDataSpaceSummary(
          selectionKey: 'local-space-1',
          displayIndex: 1,
          profileCreatedDate: '2026-07-26',
          latestBusinessUpdatedAt: null,
          todayCount: 0,
          journalCount: 0,
          goalCount: 0,
          healthCount: 0,
          aiReportCount: 0,
          tombstoneCount: 0,
          hasSyncHistory: false,
          hasConflictHistory: false,
          hasAiPending: false,
          isAlreadyBound: false,
        ),
      ],
    );
  }
}
