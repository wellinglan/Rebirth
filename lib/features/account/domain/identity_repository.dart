import 'auth_identity.dart';

abstract interface class IdentityRepository {
  Future<List<AuthIdentity>> getCurrentIdentities();

  Future<ReauthenticationProof> reauthenticate({
    required ReauthenticationMethod method,
    required String credential,
  });

  Future<WechatBindingStartResult> startWechatBinding({
    required String reauthenticationProof,
  });
}
