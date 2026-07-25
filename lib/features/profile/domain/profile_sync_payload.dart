import 'package:rebirth/features/sync/domain/sync_models.dart';

final class ProfileSyncPayload implements SyncEntityPayload {
  const ProfileSyncPayload({
    required this.displayName,
    required this.growthFocus,
    required this.timezoneId,
    required this.updatedAt,
  });

  final String? displayName;
  final String? growthFocus;
  final String timezoneId;
  final int updatedAt;
}
