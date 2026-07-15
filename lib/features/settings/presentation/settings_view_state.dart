import 'package:rebirth/features/account/domain/account_status.dart';
import 'package:rebirth/features/account/domain/sync_status.dart';
import 'package:rebirth/features/profile/domain/device_profile_status.dart';
import 'package:rebirth/features/profile/domain/user_profile.dart';

final class SettingsViewState {
  const SettingsViewState({
    required this.profile,
    required this.deviceStatus,
    this.accountStatus = const AccountStatus.localOnly(),
    this.accountSyncStatus = const AccountSyncStatus.disabled(),
  });

  final UserProfile profile;
  final DeviceProfileStatus? deviceStatus;
  final AccountStatus accountStatus;
  final AccountSyncStatus accountSyncStatus;

  bool get isLocalMode => deviceStatus?.isLocalMode ?? true;

  bool get syncEnabled => deviceStatus?.syncEnabled ?? false;
}
