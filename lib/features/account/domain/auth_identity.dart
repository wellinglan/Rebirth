enum AuthIdentityProvider {
  password,
  developer,
  wechat,
  other;

  factory AuthIdentityProvider.fromWire(String value) {
    return switch (value) {
      'password' || 'password_username' => AuthIdentityProvider.password,
      'developer' || 'dev' => AuthIdentityProvider.developer,
      'wechat' => AuthIdentityProvider.wechat,
      _ => AuthIdentityProvider.other,
    };
  }

  String get label => switch (this) {
    AuthIdentityProvider.password => '用户名密码',
    AuthIdentityProvider.developer => '开发账号',
    AuthIdentityProvider.wechat => '微信',
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

final class WechatBindingStartResult {
  const WechatBindingStartResult({
    required this.status,
    required this.provider,
    required this.requiresReauthentication,
    required this.message,
  });

  final String status;
  final AuthIdentityProvider provider;
  final bool requiresReauthentication;
  final String message;

  bool get isProviderUnavailable => status == 'provider_unavailable';
}
