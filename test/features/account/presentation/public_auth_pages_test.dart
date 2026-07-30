import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/config/app_config.dart';
import 'package:rebirth/core/config/app_config_provider.dart';
import 'package:rebirth/features/account/domain/app_auth_state.dart';
import 'package:rebirth/features/account/presentation/app_auth_controller.dart';
import 'package:rebirth/features/account/presentation/developer_login_page.dart';
import 'package:rebirth/features/account/presentation/login_page.dart';
import 'package:rebirth/features/account/presentation/register_page.dart';

void main() {
  testWidgets('public login is the primary production entry', (tester) async {
    final controller = _FakeAppAuthController();
    await _pump(
      tester,
      const PublicLoginPage(),
      controller: controller,
      config: AppConfig.fromValues(
        environmentValue: 'production',
        serverEndpoint: 'https://api.example.invalid',
        enableDevLoginValue: 'true',
      ),
    );

    expect(find.byKey(const ValueKey('loginUsernameField')), findsOneWidget);
    expect(find.byKey(const ValueKey('loginPasswordField')), findsOneWidget);
    expect(find.byKey(const ValueKey('openRegisterButton')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('openDeveloperLoginButton')),
      findsNothing,
    );
    expect(find.text('Development User Key'), findsNothing);
    expect(find.textContaining('https://'), findsNothing);
    expect(find.byKey(const ValueKey('alphaEnvironmentBadge')), findsNothing);
  });

  testWidgets('alpha shows a low-priority developer entry', (tester) async {
    await _pump(
      tester,
      const PublicLoginPage(),
      controller: _FakeAppAuthController(),
      config: AppConfig.fromValues(
        environmentValue: 'alpha',
        serverEndpoint: 'https://api.example.invalid',
        enableDevLoginValue: 'true',
      ),
    );

    expect(find.byKey(const ValueKey('alphaEnvironmentBadge')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('openDeveloperLoginButton')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('developerUserKeyField')), findsNothing);
  });

  testWidgets('login validates, toggles visibility, and submits once', (
    tester,
  ) async {
    final pending = Completer<bool>();
    final controller = _FakeAppAuthController(loginResult: pending.future);
    await _pump(tester, const PublicLoginPage(), controller: controller);

    await tester.tap(find.byKey(const ValueKey('loginSubmitButton')));
    await tester.pump();
    expect(find.text('请输入用户名'), findsOneWidget);
    expect(find.text('请输入密码'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('loginUsernameField')),
      'Account.User',
    );
    await tester.enterText(
      find.byKey(const ValueKey('loginPasswordField')),
      ' private password ',
    );
    final passwordField = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('loginPasswordField')),
        matching: find.byType(EditableText),
      ),
    );
    expect(passwordField.obscureText, isTrue);
    await tester.tap(
      find.byKey(const ValueKey('loginPasswordVisibilityButton')),
    );
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('loginPasswordField')),
              matching: find.byType(EditableText),
            ),
          )
          .obscureText,
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey('loginSubmitButton')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('loginSubmitButton')));
    expect(controller.loginCalls, 1);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('loginSubmitButton')))
          .onPressed,
      isNull,
    );

    pending.complete(false);
    await tester.pumpAndSettle();
    expect(controller.lastUsername, 'Account.User');
    expect(controller.lastPassword, ' private password ');
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('loginUsernameField')),
          )
          .controller
          ?.text,
      'Account.User',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('loginPasswordField')),
          )
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets(
    'registration validates confirmation and normalizes display name',
    (tester) async {
      final controller = _FakeAppAuthController();
      await _pump(tester, const PublicRegisterPage(), controller: controller);

      await tester.enterText(
        find.byKey(const ValueKey('registerUsernameField')),
        'New.User',
      );
      await tester.enterText(
        find.byKey(const ValueKey('registerDisplayNameField')),
        '  New User  ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('registerPasswordField')),
        'registration password',
      );
      await tester.enterText(
        find.byKey(const ValueKey('registerConfirmationField')),
        'different password',
      );
      await tester.tap(find.byKey(const ValueKey('registerSubmitButton')));
      await tester.pump();
      expect(find.text('两次输入的密码不一致'), findsOneWidget);
      expect(controller.registerCalls, 0);

      await tester.enterText(
        find.byKey(const ValueKey('registerConfirmationField')),
        'registration password',
      );
      await tester.tap(find.byKey(const ValueKey('registerSubmitButton')));
      await tester.pumpAndSettle();

      expect(controller.registerCalls, 1);
      expect(controller.lastDisplayName, 'New User');
    },
  );

  testWidgets('developer key is cleared immediately after submission', (
    tester,
  ) async {
    final controller = _FakeAppAuthController();
    await _pump(
      tester,
      const DeveloperLoginPage(),
      controller: controller,
      config: const AppConfig.test(enableDevLogin: true),
    );

    await tester.enterText(
      find.byKey(const ValueKey('developerUserKeyField')),
      'temporary-key',
    );
    await tester.tap(find.byKey(const ValueKey('developerLoginSubmitButton')));
    await tester.pumpAndSettle();

    expect(controller.developerCalls, 1);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('developerUserKeyField')),
          )
          .controller
          ?.text,
      isEmpty,
    );
  });

  for (final width in [320.0, 360.0, 412.0, 1200.0]) {
    testWidgets('login has no overflow at ${width.toInt()}px and 2x text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(
        tester,
        MediaQuery(
          data: MediaQueryData(
            size: Size(width, 900),
            textScaler: const TextScaler.linear(2),
          ),
          child: const PublicLoginPage(),
        ),
        controller: _FakeAppAuthController(),
      );

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required _FakeAppAuthController controller,
  AppConfig config = const AppConfig.test(enableDevLogin: false),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        appAuthControllerProvider.overrideWith(() => controller),
      ],
      child: MaterialApp(theme: ThemeData(useMaterial3: true), home: child),
    ),
  );
  await tester.pumpAndSettle();
}

final class _FakeAppAuthController extends AppAuthController {
  _FakeAppAuthController({this.loginResult});

  final Future<bool>? loginResult;
  int loginCalls = 0;
  int registerCalls = 0;
  int developerCalls = 0;
  String? lastUsername;
  String? lastPassword;
  String? lastDisplayName;

  @override
  Future<AppAuthState> build() async => const AppAuthState.signedOut();

  @override
  Future<bool> loginWithPassword({
    required String username,
    required String password,
  }) async {
    loginCalls += 1;
    lastUsername = username;
    lastPassword = password;
    state = const AsyncData(
      AppAuthState(status: AppAuthStatus.submittingLogin),
    );
    final result = await (loginResult ?? Future.value(false));
    state = const AsyncData(AppAuthState.signedOut(message: '用户名或密码不正确。'));
    return result;
  }

  @override
  Future<bool> registerWithPassword({
    required String username,
    required String password,
    String? displayName,
  }) async {
    registerCalls += 1;
    lastUsername = username;
    lastPassword = password;
    lastDisplayName = displayName;
    return false;
  }

  @override
  Future<bool> devLogin(String devUserKey) async {
    developerCalls += 1;
    return false;
  }
}
