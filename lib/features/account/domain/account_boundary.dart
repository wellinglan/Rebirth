final class CloudAccountScope {
  const CloudAccountScope({
    required this.endpointKey,
    required this.cloudUserId,
  });

  final String endpointKey;
  final String cloudUserId;
}

enum AccountBindingResolutionStatus { activated, bindingRequired }

final class AccountBindingResolution {
  const AccountBindingResolution._({
    required this.status,
    this.localUserId,
    this.unboundProfileCount = 0,
  });

  const AccountBindingResolution.activated(String localUserId)
    : this._(
        status: AccountBindingResolutionStatus.activated,
        localUserId: localUserId,
      );

  const AccountBindingResolution.bindingRequired(int unboundProfileCount)
    : this._(
        status: AccountBindingResolutionStatus.bindingRequired,
        unboundProfileCount: unboundProfileCount,
      );

  final AccountBindingResolutionStatus status;
  final String? localUserId;
  final int unboundProfileCount;

  bool get isActivated =>
      status == AccountBindingResolutionStatus.activated && localUserId != null;
}

final class AccountScopeMismatchException implements Exception {
  const AccountScopeMismatchException([
    this.message = '当前云账号与本地数据空间不匹配，已停止同步。',
  ]);

  final String message;

  @override
  String toString() => message;
}

final class AccountSessionRejectedException implements Exception {
  const AccountSessionRejectedException([
    this.message = '当前登录会话与服务器不匹配，请重新登录。',
  ]);

  final String message;

  @override
  String toString() => message;
}
