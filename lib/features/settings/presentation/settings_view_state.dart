import 'package:rebirth/features/profile/domain/device_profile_status.dart';
import 'package:rebirth/features/profile/domain/user_profile.dart';

final class SettingsViewState {
  const SettingsViewState({required this.profile, required this.deviceStatus});

  final UserProfile profile;
  final DeviceProfileStatus? deviceStatus;

  bool get isLocalMode => deviceStatus?.isLocalMode ?? true;

  bool get syncEnabled => deviceStatus?.syncEnabled ?? false;
}
