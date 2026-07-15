import 'package:rebirth/features/account/domain/auth_session.dart';

abstract interface class AuthSessionStore {
  Future<AuthSession?> read();

  Future<void> save(AuthSession session);

  Future<void> clear();
}
