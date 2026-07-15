final class AccountAuthenticationRequiredException implements Exception {
  const AccountAuthenticationRequiredException();

  @override
  String toString() => '请先开发登录';
}
