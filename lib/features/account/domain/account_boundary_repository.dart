import 'package:rebirth/core/database/app_database.dart';

import 'account_boundary.dart';
import 'auth_session.dart';

abstract interface class AccountBoundaryRepository {
  Future<InstallationInfoRow> ensureInstallation();

  Future<AccountBindingResolution> resolveAndActivate(AuthSession session);

  Future<List<LegacyLocalDataSpaceCandidate>> listLegacyDataSpaces();

  Future<AccountBindingResolution> claimLegacyDataSpace({
    required AuthSession session,
    required CloudAccountScope expectedScope,
    required String localUserId,
  });

  Future<AccountBindingResolution> createFreshDataSpace({
    required AuthSession session,
    required CloudAccountScope expectedScope,
  });

  Future<void> deactivateAllProfiles();

  Future<String> requireActiveScope({
    required String endpoint,
    required String cloudUserId,
  });
}
