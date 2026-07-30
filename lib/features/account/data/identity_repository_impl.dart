import 'package:rebirth/features/account/domain/auth_identity.dart';
import 'package:rebirth/features/account/domain/identity_repository.dart';

import 'auth_session_manager.dart';
import 'identity_api_data_source.dart';

final class IdentityRepositoryImpl implements IdentityRepository {
  const IdentityRepositoryImpl(this._sessionManager, this._remoteDataSource);

  final AuthSessionManager _sessionManager;
  final IdentityRemoteDataSource _remoteDataSource;

  @override
  Future<List<AuthIdentity>> getCurrentIdentities() {
    return _sessionManager.runAuthorized(
      (accessToken) =>
          _remoteDataSource.getCurrentIdentities(accessToken: accessToken),
    );
  }
}
