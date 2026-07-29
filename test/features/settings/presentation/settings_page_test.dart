import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/config/app_config.dart';
import 'package:rebirth/core/config/app_config_provider.dart';
import 'package:rebirth/features/account/domain/account_status.dart';
import 'package:rebirth/features/account/domain/app_auth_state.dart';
import 'package:rebirth/features/account/presentation/account_controller.dart';
import 'package:rebirth/features/account/presentation/account_view_state.dart';
import 'package:rebirth/features/account/presentation/app_auth_controller.dart';
import 'package:rebirth/features/journal/domain/journal_prompt.dart';
import 'package:rebirth/features/journal/presentation/journal_prompt_controller.dart';
import 'package:rebirth/features/profile/domain/user_profile.dart';
import 'package:rebirth/features/settings/presentation/settings_controller.dart';
import 'package:rebirth/features/settings/presentation/settings_page.dart';
import 'package:rebirth/features/settings/presentation/settings_view_state.dart';
import 'package:rebirth/features/sync/application/sync_module_registry.dart';
import 'package:rebirth/features/sync/presentation/sync_center_controller.dart';
import 'package:rebirth/features/sync/presentation/sync_center_view_state.dart';

void main() {
  testWidgets(
    'top-level Settings exposes the user-facing information architecture',
    (tester) async {
      await _pumpSettings(tester);

      for (final label in const [
        '账号',
        '数据与同步',
        '个人数据与隐私',
        'Journal',
        '高级设置',
        '关于 Rebirth',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('accountSettingsTile')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('syncCenterSettingsTile')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('developerOptionsSettingsTile')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'ordinary Settings hides development and directional sync details',
    (tester) async {
      await _pumpSettings(tester);

      for (final forbidden in const [
        'Development User Key',
        'Device ID',
        '服务器地址',
        'Endpoint',
        '上传 Profile',
        '拉取 Profile',
        '微信登录',
        '同步设置',
      ]) {
        expect(find.textContaining(forbidden), findsNothing);
      }
      expect(find.text('同步 Profile'), findsNothing);
      expect(find.text('同步 Plan'), findsNothing);
      expect(find.text('同步 Today'), findsNothing);
      expect(find.text('同步 Journal'), findsNothing);
      expect(find.text('同步 Health'), findsNothing);
    },
  );

  testWidgets('developer entry is omitted when development login is disabled', (
    tester,
  ) async {
    await _pumpSettings(tester, enableDevLogin: false);

    expect(find.text('高级设置'), findsNothing);
    expect(
      find.byKey(const ValueKey('developerOptionsSettingsTile')),
      findsNothing,
    );
  });

  for (final scenario in <(AppAuthState, String)>[
    (const AppAuthState.signedOut(), '本地模式'),
    (const AppAuthState(status: AppAuthStatus.authenticated), '云端已连接'),
    (const AppAuthState(status: AppAuthStatus.authenticatedOffline), '离线可用'),
    (const AppAuthState(status: AppAuthStatus.bindingRequired), '需要确认本地数据归属'),
    (const AppAuthState(status: AppAuthStatus.sessionRejected), '会话已失效'),
  ]) {
    testWidgets('account summary renders ${scenario.$1.status.name}', (
      tester,
    ) async {
      await _pumpSettings(tester, authState: scenario.$1);
      expect(find.textContaining(scenario.$2), findsOneWidget);
    });
  }

  testWidgets('loading and error states remain actionable', (tester) async {
    final gate = Completer<SettingsViewState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(settingsGate: gate.future),
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('settingsLoadingState')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(settingsError: StateError('failed')),
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settingsErrorState')), findsOneWidget);
    expect(find.byKey(const ValueKey('retrySettingsButton')), findsOneWidget);
  });

  testWidgets(
    'top-level Settings remains scrollable at 320px and text scale 2',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(),
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(320, 720),
                textScaler: TextScaler.linear(2),
              ),
              child: SettingsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scrollable), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  bool enableDevLogin = true,
  AppAuthState authState = const AppAuthState.signedOut(),
  Future<SettingsViewState>? settingsGate,
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(
        enableDevLogin: enableDevLogin,
        authState: authState,
        settingsGate: settingsGate,
      ),
      child: const MaterialApp(home: SettingsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

dynamic _overrides({
  bool enableDevLogin = true,
  AppAuthState authState = const AppAuthState.signedOut(),
  Future<SettingsViewState>? settingsGate,
  Object? settingsError,
}) {
  return [
    appConfigProvider.overrideWithValue(
      AppConfig(
        apiBaseUrl: 'http://127.0.0.1:8000',
        enableDevLogin: enableDevLogin,
        appVersionLabel: 'test',
      ),
    ),
    settingsControllerProvider.overrideWith(
      () => _FakeSettingsController(
        settingsGate ?? Future.value(_settings),
        error: settingsError,
      ),
    ),
    accountControllerProvider.overrideWith(
      () => _FakeAccountController(
        const AccountViewState(
          status: AccountStatus.localOnly(backendConfigured: true),
        ),
      ),
    ),
    appAuthStateProvider.overrideWithValue(AsyncData(authState)),
    syncCenterControllerProvider.overrideWith(
      () => _FakeSyncCenterController(
        SyncCenterViewState(
          modules: createDefaultSyncModuleRegistry().orderedModules,
        ),
      ),
    ),
    journalPromptControllerProvider.overrideWith(
      () => _FakeJournalPromptController(_prompts),
    ),
  ];
}

final _settings = SettingsViewState(
  profile: const UserProfile(
    id: 'local-user',
    displayName: '测试用户',
    growthFocus: null,
    timezoneId: 'Asia/Shanghai',
    createdAt: 1,
    updatedAt: 1,
  ),
  deviceStatus: null,
);

final _prompts = JournalPromptConfiguration(
  id: 'configuration',
  userId: 'local-user',
  logicalKey: 'default',
  configurationVersion: 1,
  createdAt: 1,
  updatedAt: 1,
  syncStatus: 'synced',
  serverVersion: 1,
  lastSyncedAt: 1,
  originDeviceId: null,
  deletedAt: null,
  prompts: const [],
);

final class _FakeSettingsController extends SettingsController {
  _FakeSettingsController(this.value, {this.error});
  final Future<SettingsViewState> value;
  final Object? error;

  @override
  Future<SettingsViewState> build() async {
    if (error case final exception?) throw exception;
    return value;
  }
}

final class _FakeAccountController extends AccountController {
  _FakeAccountController(this.value);
  final AccountViewState value;

  @override
  Future<AccountViewState> build() async => value;
}

final class _FakeSyncCenterController extends SyncCenterController {
  _FakeSyncCenterController(this.value);
  final SyncCenterViewState value;

  @override
  Future<SyncCenterViewState> build() async => value;
}

final class _FakeJournalPromptController extends JournalPromptController {
  _FakeJournalPromptController(this.value);
  final JournalPromptConfiguration value;

  @override
  Future<JournalPromptConfiguration> build() async => value;
}
