import 'package:rebirth/features/account/domain/auth_identity.dart';

final class AccountSecurityState {
  const AccountSecurityState({
    required this.identities,
    this.isOfflineSnapshot = false,
    this.isStartingWechatBinding = false,
  });

  final List<AuthIdentity> identities;
  final bool isOfflineSnapshot;
  final bool isStartingWechatBinding;

  bool get hasWechatIdentity => identities.any(
    (identity) => identity.provider == AuthIdentityProvider.wechat,
  );

  AccountSecurityState copyWith({
    List<AuthIdentity>? identities,
    bool? isOfflineSnapshot,
    bool? isStartingWechatBinding,
  }) {
    return AccountSecurityState(
      identities: identities ?? this.identities,
      isOfflineSnapshot: isOfflineSnapshot ?? this.isOfflineSnapshot,
      isStartingWechatBinding:
          isStartingWechatBinding ?? this.isStartingWechatBinding,
    );
  }
}
