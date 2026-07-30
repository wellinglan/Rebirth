enum AuthIdentityProvider {
  password,
  developer,
  other;

  factory AuthIdentityProvider.fromWire(String value) {
    return switch (value) {
      'password' || 'password_username' => AuthIdentityProvider.password,
      'developer' || 'dev' => AuthIdentityProvider.developer,
      _ => AuthIdentityProvider.other,
    };
  }

  String get label => switch (this) {
    AuthIdentityProvider.password => '用户名密码',
    AuthIdentityProvider.developer => '开发账号',
    AuthIdentityProvider.other => '其他登录方式',
  };
}

final class AuthIdentity {
  const AuthIdentity({
    required this.provider,
    required this.createdAt,
    required this.lastUsedAt,
  });

  final AuthIdentityProvider provider;
  final int createdAt;
  final int? lastUsedAt;
}
