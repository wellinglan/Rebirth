import 'dart:io';

import 'package:drift/drift.dart' show Value;
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
import 'package:rebirth/features/account/domain/app_auth_state.dart';
import 'package:rebirth/features/account/presentation/app_auth_controller.dart';
import 'package:rebirth/features/ai_coach/data/ai_coach_repository_providers.dart';
import 'package:rebirth/features/journal/data/journal_prompt_repository_impl.dart';

import '../../ai_coach/ai_coach_test_support.dart';

void main() {
  testWidgets('Settings opens globally and Profile returns an updated name', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final bootstrap = await database.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );
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
          appAuthStateProvider.overrideWithValue(
            AsyncData(
              AppAuthState(
                status: AppAuthStatus.authenticated,
                localUserId: bootstrap.activeUserId,
                cloudUserId: 'settings-user',
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

    expect(find.byKey(const ValueKey('homeNavigationRail')), findsOneWidget);
    for (final label in ['今日', '复盘', '计划', '健康', '成长', 'AI 教练']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('Profile'), findsNothing);
    expect(find.byKey(const ValueKey('settingsEntryButton')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settingsEntryButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settingsPage')), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('仅在确认生成时发送所选汇总数据，不会自动发送'), findsOneWidget);

    final personalDataExportTile = find.byKey(
      const ValueKey('fullPersonalDataExportSettingsTile'),
    );
    await tester.ensureVisible(personalDataExportTile);
    await tester.pumpAndSettle();
    await tester.tap(personalDataExportTile);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('fullPersonalDataExportPage')),
      findsOneWidget,
    );
    expect(find.text('导出全部个人数据'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settingsPage')), findsOneWidget);
    expect(find.byKey(const ValueKey('aiCoachSettingsTile')), findsNothing);
    expect(find.byKey(const ValueKey('aiReportsSettingsTile')), findsNothing);
    final aiPrivacyTile = find.byKey(
      const ValueKey('aiDataPrivacySettingsTile'),
    );
    await tester.ensureVisible(aiPrivacyTile);
    await tester.pumpAndSettle();
    await tester.tap(aiPrivacyTile);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('aiConsentSettingsPage')), findsOneWidget);
    expect(find.byKey(const ValueKey('aiDataPrivacyCard')), findsOneWidget);
    expect(find.byKey(const ValueKey('aiCoachPage')), findsNothing);
    expect(find.byType(NavigationDestination), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settingsPage')), findsOneWidget);
    final profileTile = find.byKey(const ValueKey('profileSettingsTile'));
    await tester.ensureVisible(profileTile);
    await tester.pumpAndSettle();
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

  testWidgets(
    'Settings opens prompt management for a conflicted configuration',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final bootstrap = await database.bootstrapDao.bootstrap(
        createUnboundProfile: true,
      );
      final dateTimeService = DateTimeService(
        now: () => DateTime(2026, 7, 30, 9),
      );
      await JournalPromptRepositoryImpl(
        database: database,
        dateTimeService: dateTimeService,
      ).ensureInitialized();
      await (database.update(
        database.journalPromptConfigurations,
      )..where((row) => row.userId.equals(bootstrap.activeUserId))).write(
        const JournalPromptConfigurationsCompanion(
          syncStatus: Value('conflict'),
        ),
      );
      await tester.binding.setSurfaceSize(const Size(900, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            dateTimeServiceProvider.overrideWithValue(dateTimeService),
            authSessionStoreProvider.overrideWithValue(_MemorySessionStore()),
            appAuthStateProvider.overrideWithValue(
              AsyncData(
                AppAuthState(
                  status: AppAuthStatus.authenticated,
                  localUserId: bootstrap.activeUserId,
                  cloudUserId: 'settings-user',
                ),
              ),
            ),
          ],
          child: const RebirthApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settingsEntryButton')));
      await tester.pumpAndSettle();

      final promptTile = find.byKey(
        const ValueKey('journalPromptSettingsTile'),
      );
      await tester.drag(
        find.byKey(const ValueKey('settingsDataState')),
        const Offset(0, -320),
      );
      await tester.pumpAndSettle();
      await tester.tap(promptTile);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('journalPromptManagementPage')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('journalPromptLoadingState')),
        findsNothing,
      );
      expect(find.text('使用中的问题'), findsOneWidget);
      expect(find.text('同步状态：存在冲突，请到同步中心处理'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
      expect(databaseSource, contains('int get schemaVersion => 12'));
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
