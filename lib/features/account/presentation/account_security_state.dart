import 'package:rebirth/features/account/domain/auth_identity.dart';

final class AccountSecurityState {
  const AccountSecurityState({
    required this.identities,
    this.isOfflineSnapshot = false,
  });

  final List<AuthIdentity> identities;
  final bool isOfflineSnapshot;
}
