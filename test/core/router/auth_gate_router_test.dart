import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/app/rebirth_app.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/features/account/domain/app_auth_state.dart';
import 'package:rebirth/features/account/presentation/app_auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  testWidgets('signed-out login can validate and save the Alpha endpoint', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
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

    await tester.tap(
      find.byKey(const ValueKey('configureLoginServerEndpointButton')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('loginServerEndpointField')),
      'ftp://invalid.example.test',
    );
    await tester.tap(
      find.byKey(const ValueKey('saveLoginServerEndpointButton')),
    );
    await tester.pump();
    expect(find.textContaining('HTTP 或 HTTPS'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('loginServerEndpointField')),
      'http://192.168.31.129:8000/',
    );
    await tester.tap(
      find.byKey(const ValueKey('saveLoginServerEndpointButton')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('当前 Alpha 服务器：http://192.168.31.129:8000'),
      findsOneWidget,
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
}
