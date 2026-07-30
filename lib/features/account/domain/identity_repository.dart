import 'auth_identity.dart';

abstract interface class IdentityRepository {
  Future<List<AuthIdentity>> getCurrentIdentities();
}
