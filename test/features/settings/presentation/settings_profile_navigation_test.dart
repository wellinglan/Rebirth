import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/app/rebirth_app.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';

void main() {
  testWidgets('Settings opens globally and Profile returns an updated name', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          dateTimeServiceProvider.overrideWithValue(
            DateTimeService(now: () => DateTime(2026, 7, 15, 9)),
          ),
          authSessionStoreProvider.overrideWithValue(_MemorySessionStore()),
        ],
        child: const RebirthApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(5));
    for (final label in ['今日', '复盘', '计划', '健康', '成长']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('Profile'), findsNothing);
    expect(find.byKey(const ValueKey('settingsEntryButton')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settingsEntryButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settingsPage')), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    final profileTile = find.byKey(const ValueKey('profileSettingsTile'));
    await Scrollable.ensureVisible(tester.element(profileTile));
    await tester.tap(profileTile);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profilePage')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('profileDisplayNameField')),
      '跨页刷新昵称',
    );
    final saveButton = find.byKey(const ValueKey('saveProfileButton'));
    await Scrollable.ensureVisible(tester.element(saveButton));
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.text('资料已保存'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settingsPage')), findsOneWidget);
    expect(find.text('跨页刷新昵称'), findsOneWidget);
    final stored = await database.select(database.userProfiles).getSingle();
    expect(stored.displayName, '跨页刷新昵称');
  });

  test(
    'Settings/Profile architecture keeps future auth boundaries explicit',
    () {
      final revisionSource = File(
        'lib/shared/state/profile_revision_provider.dart',
      ).readAsStringSync();
      final routerSource = File(
        'lib/core/router/app_router.dart',
      ).readAsStringSync();
      final routeNamesSource = File(
        'lib/core/router/route_names.dart',
      ).readAsStringSync();
      final databaseSource = File(
        'lib/core/database/app_database.dart',
      ).readAsStringSync();
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(revisionSource, isNot(contains('features/')));
      expect(routeNamesSource, contains("'/settings/profile'"));
      expect(routerSource, isNot(contains('RoutePaths.profile')));
      expect(databaseSource, contains('int get schemaVersion => 3'));
      expect(pubspec, isNot(contains('firebase_auth')));
      expect(pubspec, isNot(contains('supabase')));
      expect(pubspec, isNot(contains('oauth')));
    },
  );
}

final class _MemorySessionStore implements AuthSessionStore {
  AuthSession? session;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> save(AuthSession session) async {
    this.session = session;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}
