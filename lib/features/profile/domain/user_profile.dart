final class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.growthFocus,
    required this.timezoneId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? displayName;
  final String? growthFocus;
  final String timezoneId;
  final int createdAt;
  final int updatedAt;
}
