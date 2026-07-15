import 'account_status.dart';
import 'auth_session.dart';

abstract interface class AuthRepository {
  Future<AccountStatus> getAccountStatus();

  Future<AuthSession> devLogin(String devUserKey);

  Future<void> logout();

  Future<void> refreshSession();
}
