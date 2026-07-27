import 'legacy_ownership_verification.dart';

abstract interface class LegacyOwnershipVerificationRepository {
  Future<LegacyOwnershipVerificationResult> verifyCurrentDataSpace();
}
