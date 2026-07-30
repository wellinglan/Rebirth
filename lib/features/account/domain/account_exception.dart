final class AccountAuthenticationRequiredException implements Exception {
  const AccountAuthenticationRequiredException();

  @override
  String toString() => '请先登录';
}
