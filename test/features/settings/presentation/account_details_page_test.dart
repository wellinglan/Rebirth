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
import 'package:rebirth/features/profile/domain/user_profile.dart';
import 'package:rebirth/features/settings/presentation/account_details_page.dart';
import 'package:rebirth/features/settings/presentation/settings_controller.dart';
import 'package:rebirth/features/settings/presentation/settings_view_state.dart';

void main() {
  testWidgets('account page shows understandable Alpha account status', (
    tester,
  ) async {
    await _pump(tester, enableDevLogin: true);

    expect(find.text('账号'), findsOneWidget);
    expect(find.textContaining('Alpha 环境'), findsOneWidget);
    expect(find.text('开发账号'), findsOneWidget);
    expect(find.text('账号模式'), findsOneWidget);
    expect(find.text('登录方式'), findsOneWidget);
    expect(find.text('会话状态'), findsOneWidget);
    expect(find.text('云端连接'), findsOneWidget);
    expect(find.text('当前设备'), findsOneWidget);
    expect(find.text('同步资格'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('openDeveloperOptionsFromAccount')),
      findsOneWidget,
    );
  });

  testWidgets('account page hides technical identifiers and developer entry', (
    tester,
  ) async {
    await _pump(tester, enableDevLogin: false);

    for (final forbidden in const [
      'Token',
      'cloudUserId',
      'localUserId',
      'Device ID',
      'Endpoint',
      'JWT',
      'database',
      '11111111-1111-4111-8111-111111111111',
    ]) {
      expect(find.textContaining(forbidden), findsNothing);
    }
    expect(
      find.byKey(const ValueKey('openDeveloperOptionsFromAccount')),
      findsNothing,
    );
  });

  testWidgets('account page has no overflow at 320px and text scale 2', (
    tester,
  ) async {
    await _pump(tester, width: 320, textScale: 2);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  bool enableDevLogin = true,
  double width = 900,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig(
            environment: enableDevLogin
                ? AppEnvironment.alpha
                : AppEnvironment.production,
            apiBaseUrl: 'http://127.0.0.1:8000',
            enableDevLogin: enableDevLogin,
            appVersionLabel: 'test',
          ),
        ),
        settingsControllerProvider.overrideWith(_FakeSettingsController.new),
        accountControllerProvider.overrideWith(_FakeAccountController.new),
        appAuthStateProvider.overrideWithValue(
          const AsyncData(
            AppAuthState(
              status: AppAuthStatus.authenticated,
              syncEligibility: null,
              identityProvider: 'dev',
              displayName: '测试用户',
            ),
          ),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 1000),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const AccountDetailsPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _FakeSettingsController extends SettingsController {
  @override
  Future<SettingsViewState> build() async {
    return const SettingsViewState(
      profile: UserProfile(
        id: 'local-user',
        displayName: '测试用户',
        growthFocus: null,
        timezoneId: 'Asia/Shanghai',
        createdAt: 1,
        updatedAt: 1,
      ),
      deviceStatus: null,
    );
  }
}

final class _FakeAccountController extends AccountController {
  @override
  Future<AccountViewState> build() async {
    return const AccountViewState(
      status: AccountStatus(
        mode: AccountMode.cloud,
        authentication: AuthenticationStatus.signedIn,
        backendConfigured: true,
        backendReachable: true,
      ),
    );
  }
}
