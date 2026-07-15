final class ProfileSaveData {
  factory ProfileSaveData({String? displayName, String? growthFocus}) {
    return ProfileSaveData._(
      displayName: _trimToNull(displayName),
      growthFocus: _trimToNull(growthFocus),
    );
  }

  const ProfileSaveData._({
    required this.displayName,
    required this.growthFocus,
  });

  final String? displayName;
  final String? growthFocus;

  static String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
