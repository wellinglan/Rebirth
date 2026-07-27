final class CloudAccountScope {
  const CloudAccountScope({
    required this.endpointKey,
    required this.cloudUserId,
  });

  final String endpointKey;
  final String cloudUserId;

  bool matches(CloudAccountScope other) =>
      endpointKey == other.endpointKey && cloudUserId == other.cloudUserId;
}

enum AccountBindingResolutionStatus { activated, bindingRequired }

enum AccountBindingOrigin {
  cleanFirstLogin('clean_first_login'),
  freshSpace('fresh_space'),
  legacyClaim('legacy_claim');

  const AccountBindingOrigin(this.wireValue);

  final String wireValue;

  static AccountBindingOrigin fromWire(String value) {
    return values.firstWhere(
      (candidate) => candidate.wireValue == value,
      orElse: () => throw StateError('Unknown binding origin.'),
    );
  }
}

enum AccountSyncEligibility {
  ready('ready'),
  legacyReviewRequired('legacy_review_required');

  const AccountSyncEligibility(this.wireValue);

  final String wireValue;

  static AccountSyncEligibility fromWire(String value) {
    return values.firstWhere(
      (candidate) => candidate.wireValue == value,
      orElse: () => throw StateError('Unknown sync eligibility.'),
    );
  }
}

enum AccountOwnershipVerificationStatus {
  notVerified('not_verified'),
  verified('verified'),
  failed('failed');

  const AccountOwnershipVerificationStatus(this.wireValue);

  final String wireValue;

  static AccountOwnershipVerificationStatus fromWire(String value) {
    return values.firstWhere(
      (candidate) => candidate.wireValue == value,
      orElse: () => throw StateError('Unknown ownership verification status.'),
    );
  }
}

enum AccountOwnershipVerificationMethod {
  accountSpaceCreation('account_space_creation'),
  serverSyncMetadataV1('server_sync_metadata_v1');

  const AccountOwnershipVerificationMethod(this.wireValue);

  final String wireValue;
}

final class AccountBindingResolution {
  const AccountBindingResolution._({
    required this.status,
    this.localUserId,
    this.accountScope,
    this.syncEligibility,
    this.verificationStatus,
    this.verificationReason,
    this.unboundProfileCount = 0,
  });

  const AccountBindingResolution.activated({
    required String localUserId,
    required CloudAccountScope accountScope,
    required AccountSyncEligibility syncEligibility,
    AccountOwnershipVerificationStatus verificationStatus =
        AccountOwnershipVerificationStatus.verified,
    String? verificationReason,
  }) : this._(
         status: AccountBindingResolutionStatus.activated,
         localUserId: localUserId,
         accountScope: accountScope,
         syncEligibility: syncEligibility,
         verificationStatus: verificationStatus,
         verificationReason: verificationReason,
       );

  const AccountBindingResolution.bindingRequired({
    required int unboundProfileCount,
    required CloudAccountScope accountScope,
  }) : this._(
         status: AccountBindingResolutionStatus.bindingRequired,
         accountScope: accountScope,
         unboundProfileCount: unboundProfileCount,
       );

  final AccountBindingResolutionStatus status;
  final String? localUserId;
  final CloudAccountScope? accountScope;
  final AccountSyncEligibility? syncEligibility;
  final AccountOwnershipVerificationStatus? verificationStatus;
  final String? verificationReason;
  final int unboundProfileCount;

  bool get isActivated =>
      status == AccountBindingResolutionStatus.activated && localUserId != null;
}

final class LegacyLocalDataSpaceSummary {
  const LegacyLocalDataSpaceSummary({
    required this.selectionKey,
    required this.displayIndex,
    required this.profileCreatedDate,
    required this.latestBusinessUpdatedAt,
    required this.todayCount,
    required this.journalCount,
    required this.goalCount,
    required this.healthCount,
    required this.aiReportCount,
    required this.tombstoneCount,
    required this.hasSyncHistory,
    required this.hasConflictHistory,
    required this.hasAiPending,
    required this.isAlreadyBound,
  });

  final String selectionKey;
  final int displayIndex;
  final String profileCreatedDate;
  final int? latestBusinessUpdatedAt;
  final int todayCount;
  final int journalCount;
  final int goalCount;
  final int healthCount;
  final int aiReportCount;
  final int tombstoneCount;
  final bool hasSyncHistory;
  final bool hasConflictHistory;
  final bool hasAiPending;
  final bool isAlreadyBound;

  String get displayLabel => '本地数据空间 $displayIndex';
}

final class LegacyLocalDataSpaceCandidate {
  const LegacyLocalDataSpaceCandidate({
    required this.localUserId,
    required this.summary,
  });

  final String localUserId;
  final LegacyLocalDataSpaceSummary summary;
}

final class AccountScopeMismatchException implements Exception {
  const AccountScopeMismatchException([
    this.message = '当前云账号与本地数据空间不匹配，已停止同步。',
  ]);

  final String message;

  @override
  String toString() => message;
}

final class AccountSyncReviewRequiredException implements Exception {
  const AccountSyncReviewRequiredException([
    this.message = '该本地数据空间已归属当前账号，但旧同步元数据尚未验证，云同步暂不可用。',
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
