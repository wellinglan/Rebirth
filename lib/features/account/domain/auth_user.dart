final class AuthUser {
  const AuthUser({required this.id, required this.displayName});

  final String id;
  final String? displayName;

  bool get hasDisplayName => displayName?.trim().isNotEmpty ?? false;

  @override
  bool operator ==(Object other) {
    return other is AuthUser &&
        other.id == id &&
        other.displayName == displayName;
  }

  @override
  int get hashCode => Object.hash(id, displayName);
}
