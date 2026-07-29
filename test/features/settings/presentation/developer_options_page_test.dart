import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/config/app_config.dart';
import 'package:rebirth/core/config/app_config_provider.dart';
import 'package:rebirth/core/config/server_endpoint.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/features/account/domain/account_status.dart';
import 'package:rebirth/features/account/domain/legacy_ownership_verification.dart';
import 'package:rebirth/features/account/presentation/account_controller.dart';
import 'package:rebirth/features/account/presentation/account_view_state.dart';
import 'package:rebirth/features/account/presentation/legacy_ownership_verification_controller.dart';
import 'package:rebirth/features/settings/presentation/developer_options_page.dart';
import 'package:rebirth/features/settings/presentation/server_endpoint_settings_controller.dart';

void main() {
  testWidgets(
    'developer options are unavailable when development login is off',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(
                apiBaseUrl: 'https://example.invalid',
                enableDevLogin: false,
                appVersionLabel: 'test',
              ),
            ),
          ],
          child: const MaterialApp(home: DeveloperOptionsPage()),
        ),
      );

      expect(
        find.byKey(const ValueKey('developerOptionsUnavailable')),
        findsOneWidget,
      );
      expect(find.text('Development User Key'), findsNothing);
    },
  );

  testWidgets(
    'developer options group diagnostics without automatic network work',
    (tester) async {
      final account = _FakeAccountController();
      await _pump(tester, account: account);

      expect(find.text('开发云账号'), findsOneWidget);
      expect(find.text('开发服务器'), findsWidgets);
      expect(find.text('同步诊断'), findsOneWidget);
      expect(find.byKey(const ValueKey('devLoginButton')), findsOneWidget);
      expect(find.byKey(const ValueKey('checkBackendButton')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('registerDeviceButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('verifyOwnershipButton')),
        findsOneWidget,
      );
      expect(account.healthCalls, 0);
      expect(account.registrationCalls, 0);

      await tester.tap(find.byKey(const ValueKey('checkBackendButton')));
      await tester.pump();
      expect(account.healthCalls, 1);
    },
  );

  testWidgets('developer options hide secrets and private module content', (
    tester,
  ) async {
    await _pump(tester);

    for (final forbidden in const [
      'access-token',
      'refresh-token',
      'Journal answer',
      'Health note',
      'cloudUserId',
      'localUserId',
    ]) {
      expect(find.textContaining(forbidden), findsNothing);
    }
  });

  testWidgets('developer options scroll at 320px and text scale 2', (
    tester,
  ) async {
    await _pump(tester, width: 320, textScale: 2);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  _FakeAccountController? account,
  double width = 900,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final accountController = account ?? _FakeAccountController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: 'http://127.0.0.1:8000',
            enableDevLogin: true,
            appVersionLabel: 'test',
          ),
        ),
        accountControllerProvider.overrideWith(() => accountController),
        effectiveServerEndpointProvider.overrideWithValue(
          const ServerEndpoint(
            baseUrl: 'http://127.0.0.1:8000',
            source: ServerEndpointSource.defaultValue,
          ),
        ),
        serverEndpointSettingsControllerProvider.overrideWith(
          _FakeEndpointController.new,
        ),
        legacyOwnershipVerificationControllerProvider.overrideWith(
          _FakeVerificationController.new,
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 1100),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const DeveloperOptionsPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _FakeAccountController extends AccountController {
  int healthCalls = 0;
  int registrationCalls = 0;

  @override
  Future<AccountViewState> build() async {
    return const AccountViewState(
      status: AccountStatus.localOnly(backendConfigured: true),
    );
  }

  @override
  Future<bool> checkBackendHealth() async {
    healthCalls += 1;
    return true;
  }

  @override
  Future<bool> registerCurrentDevice() async {
    registrationCalls += 1;
    return true;
  }
}

final class _FakeEndpointController extends ServerEndpointSettingsController {
  @override
  ServerEndpointSettingsState build() => const ServerEndpointSettingsState();
}

final class _FakeVerificationController
    extends LegacyOwnershipVerificationController {
  @override
  Future<LegacyOwnershipVerificationResult?> build() async => null;
}
