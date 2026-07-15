import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/account/domain/account_status.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/account/domain/sync_status.dart';

void main() {
  test('local account status is signed out and backend is unconfigured', () {
    const status = AccountStatus.localOnly();

    expect(status.mode, AccountMode.localOnly);
    expect(status.authentication, AuthenticationStatus.signedOut);
    expect(status.backendConfigured, isFalse);
    expect(status.isAuthenticated, isFalse);
    expect(status.user, isNull);
  });

  test('auth session owns Rebirth tokens and user identity', () {
    const user = AuthUser(id: 'rebirth-user-1', displayName: 'Local test');
    const session = AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      user: user,
    );
    const status = AccountStatus(
      mode: AccountMode.cloud,
      authentication: AuthenticationStatus.signedIn,
      backendConfigured: true,
      user: user,
    );

    expect(session.user, user);
    expect(user.hasDisplayName, isTrue);
    expect(status.isAuthenticated, isTrue);
  });

  test('account sync availability does not claim sync is ready', () {
    const status = AccountSyncStatus.disabled();

    expect(status.availability, AccountSyncAvailability.disabled);
    expect(status.canSync, isFalse);
  });
}
