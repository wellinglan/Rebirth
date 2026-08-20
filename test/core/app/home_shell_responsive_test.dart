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

void main() {
  for (final width in <double>[320, 360, 412, 720]) {
    testWidgets('compact shell uses bottom navigation at ${width.toInt()}px', (
      tester,
    ) async {
      await _pumpApp(tester, width: width, textScale: width == 320 ? 2 : 1);

      expect(find.byKey(const ValueKey('homeNavigationBar')), findsOneWidget);
      expect(find.byKey(const ValueKey('homeNavigationRail')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('medium Windows shell uses a compact navigation rail', (
    tester,
  ) async {
    await _pumpApp(tester, width: 900);

    final rail = tester.widget<NavigationRail>(
      find.byKey(const ValueKey('homeNavigationRail')),
    );
    expect(rail.extended, isFalse);
    expect(find.byKey(const ValueKey('homeNavigationBrand')), findsNothing);
    expect(find.byKey(const ValueKey('homeNavigationBar')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide Windows shell exposes the extended Rebirth navigation', (
    tester,
  ) async {
    await _pumpApp(tester, width: 1200);

    final rail = tester.widget<NavigationRail>(
      find.byKey(const ValueKey('homeNavigationRail')),
    );
    expect(rail.extended, isTrue);
    expect(find.byKey(const ValueKey('homeNavigationBrand')), findsOneWidget);
    expect(find.text('Rebirth'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide shell stays compact at text scale 2', (tester) async {
    await _pumpApp(tester, width: 1200, textScale: 2);

    final rail = tester.widget<NavigationRail>(
      find.byKey(const ValueKey('homeNavigationRail')),
    );
    expect(rail.extended, isFalse);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required double width,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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
          DateTimeService(now: () => DateTime(2026, 8, 13, 9)),
        ),
        appAuthStateProvider.overrideWithValue(
          AsyncData(
            AppAuthState(
              status: AppAuthStatus.authenticated,
              localUserId: bootstrap.activeUserId,
              cloudUserId: 'shell-user',
            ),
          ),
        ),
      ],
      child: const RebirthApp(),
    ),
  );
  await tester.pumpAndSettle();
  final homeContext = tester.element(
    find.byKey(const ValueKey('productionHomePage')),
  );
  GoRouter.of(homeContext).go(RoutePaths.today);
  await tester.pumpAndSettle();
}
