import 'package:rebirth/features/profile/domain/user_profile.dart';

import 'profile_sync_direction.dart';

final class ProfileSyncResult {
  const ProfileSyncResult({
    required this.success,
    required this.direction,
    required this.message,
    required this.pushed,
    required this.pulled,
    required this.conflict,
    this.serverVersion,
    this.updatedProfile,
  });

  final bool success;
  final ProfileSyncDirection direction;
  final String message;
  final bool pushed;
  final bool pulled;
  final bool conflict;
  final int? serverVersion;
  final UserProfile? updatedProfile;
}
