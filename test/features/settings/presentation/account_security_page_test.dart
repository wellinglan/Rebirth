import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/account/domain/auth_identity.dart';
import 'package:rebirth/features/account/presentation/account_security_controller.dart';
import 'package:rebirth/features/account/presentation/account_security_state.dart';
import 'package:rebirth/features/settings/presentation/account_security_page.dart';

void main() {
  testWidgets('shows bound identities and disabled future WeChat entry', (
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
    expect(find.text('后续版本开放'), findsOneWidget);
    final wechat = tester.widget<ListTile>(
      find.descendant(
        of: find.byKey(const ValueKey('wechatIdentityTile')),
        matching: find.byType(ListTile),
      ),
    );
    expect(wechat.enabled, isFalse);
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
  });
}

Future<void> _pump(WidgetTester tester, AccountSecurityState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountSecurityControllerProvider.overrideWith(
          () => _FakeAccountSecurityController(state),
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

  @override
  Future<AccountSecurityState> build() async => value;
}
