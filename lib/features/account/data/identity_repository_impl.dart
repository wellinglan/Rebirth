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

  @override
  Future<ReauthenticationProof> reauthenticate({
    required ReauthenticationMethod method,
    required String credential,
  }) {
    return _sessionManager.runAuthorized(
      (accessToken) => _remoteDataSource.reauthenticate(
        accessToken: accessToken,
        method: method,
        credential: credential,
      ),
      canReplay: false,
    );
  }

  @override
  Future<WechatBindingStartResult> startWechatBinding({
    required String reauthenticationProof,
  }) {
    return _sessionManager.runAuthorized(
      (accessToken) => _remoteDataSource.startWechatBinding(
        accessToken: accessToken,
        reauthenticationProof: reauthenticationProof,
      ),
      canReplay: false,
    );
  }
}
