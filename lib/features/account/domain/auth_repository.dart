import 'account_status.dart';
import 'auth_session.dart';
import 'backend_health.dart';
import 'device_registration.dart';

abstract interface class AuthRepository {
  Future<AccountStatus> getAccountStatus();

  Future<AuthSession> devLogin(String devUserKey);

  Future<BackendHealth> checkBackendHealth();

  Future<DeviceRegistration> registerCurrentDevice();

  Future<void> logout();

  Future<void> refreshSession();
}
