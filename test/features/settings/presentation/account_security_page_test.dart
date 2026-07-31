import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/account/domain/auth_identity.dart';
import 'package:rebirth/features/account/presentation/account_security_controller.dart';
import 'package:rebirth/features/account/presentation/account_security_state.dart';
import 'package:rebirth/features/settings/presentation/account_security_page.dart';

void main() {
  testWidgets('shows bound identities and online WeChat binding entry', (
    tester,
  ) async {
    await _pump(
      tester,
      const AccountSecurityState(
        identities: [
          AuthIdentity(
            provider: AuthIdentityProvider.password,
            createdAt: 100,
            lastUsedAt: 200,
          ),
        ],
      ),
    );

    expect(find.byKey(const ValueKey('accountSecurityData')), findsOneWidget);
    expect(find.text('用户名密码'), findsOneWidget);
    expect(find.text('已绑定'), findsOneWidget);
    expect(find.text('微信'), findsOneWidget);
    expect(find.text('未绑定'), findsOneWidget);
    expect(find.byKey(const ValueKey('bindWechatButton')), findsOneWidget);
  });

  testWidgets('offline snapshot is clearly identified', (tester) async {
    await _pump(
      tester,
      const AccountSecurityState(
        identities: [
          AuthIdentity(
            provider: AuthIdentityProvider.developer,
            createdAt: 0,
            lastUsedAt: null,
          ),
        ],
        isOfflineSnapshot: true,
      ),
    );

    expect(find.text('开发账号'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('accountSecurityOfflineNote')),
      findsOneWidget,
    );
    expect(find.text('当前离线，无法绑定'), findsOneWidget);
    final button = tester.widget<TextButton>(
      find.byKey(const ValueKey('bindWechatButton')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('bound WeChat identity has no duplicate binding action', (
    tester,
  ) async {
    await _pump(
      tester,
      const AccountSecurityState(
        identities: [
          AuthIdentity(
            provider: AuthIdentityProvider.wechat,
            createdAt: 100,
            lastUsedAt: null,
          ),
        ],
      ),
    );

    expect(find.text('微信'), findsOneWidget);
    expect(find.text('已绑定'), findsOneWidget);
    expect(find.byKey(const ValueKey('bindWechatButton')), findsNothing);
  });

  testWidgets('confirmed WeChat entry calls controller and shows result', (
    tester,
  ) async {
    final controller = _FakeAccountSecurityController(
      const AccountSecurityState(
        identities: [
          AuthIdentity(
            provider: AuthIdentityProvider.password,
            createdAt: 100,
            lastUsedAt: 200,
          ),
        ],
      ),
    );
    await _pump(tester, controller.value, controller: controller);

    await tester.tap(find.byKey(const ValueKey('bindWechatButton')));
    await tester.pumpAndSettle();
    expect(find.text('绑定微信'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirmWechatBindingButton')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('reauthenticationDialog')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('reauthenticationCredentialField')),
      'private password',
    );
    await tester.tap(
      find.byKey(const ValueKey('submitReauthenticationButton')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(controller.bindingCalls, 1);
    expect(controller.lastCredential, 'private password');
    expect(find.text('当前版本尚未配置微信绑定'), findsOneWidget);
  });

  testWidgets('does not render private identity metadata', (tester) async {
    await _pump(
      tester,
      const AccountSecurityState(
        identities: [
          AuthIdentity(
            provider: AuthIdentityProvider.password,
            createdAt: 100,
            lastUsedAt: 200,
          ),
        ],
      ),
    );

    expect(find.textContaining('provider_subject'), findsNothing);
    expect(find.textContaining('cloud-user'), findsNothing);
    expect(find.textContaining('token'), findsNothing);
    expect(find.textContaining('openid'), findsNothing);
    expect(find.textContaining('unionid'), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester,
  AccountSecurityState state, {
  _FakeAccountSecurityController? controller,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountSecurityControllerProvider.overrideWith(
          () => controller ?? _FakeAccountSecurityController(state),
        ),
      ],
      child: const MaterialApp(home: AccountSecurityPage()),
    ),
  );
  await tester.pumpAndSettle();
}

final class _FakeAccountSecurityController extends AccountSecurityController {
  _FakeAccountSecurityController(this.value);

  final AccountSecurityState value;
  int bindingCalls = 0;
  String? lastCredential;

  @override
  Future<AccountSecurityState> build() async => value;

  @override
  Future<WechatBindingStartResult> startWechatBinding({
    required ReauthenticationMethod method,
    required String credential,
  }) async {
    bindingCalls += 1;
    lastCredential = credential;
    expect(method, ReauthenticationMethod.password);
    return const WechatBindingStartResult(
      status: 'provider_unavailable',
      provider: AuthIdentityProvider.wechat,
      requiresReauthentication: true,
      message: 'WeChat binding is not configured in this release.',
    );
  }
}
