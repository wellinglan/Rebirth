import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/account/domain/legacy_ownership_verification.dart';

void main() {
  for (final outcome in LegacyOwnershipVerificationOutcome.values) {
    test('${outcome.wireValue} outcome remains structured', () {
      final result = LegacyOwnershipVerificationResult(
        outcome: LegacyOwnershipVerificationOutcome.fromWire(outcome.wireValue),
        verifiedCount: outcome == LegacyOwnershipVerificationOutcome.verified
            ? 1
            : 0,
        rejectedCount: outcome == LegacyOwnershipVerificationOutcome.rejected
            ? 1
            : 0,
        unknownCount: outcome == LegacyOwnershipVerificationOutcome.unknown
            ? 1
            : 0,
        reason: switch (outcome) {
          LegacyOwnershipVerificationOutcome.verified =>
            LegacyOwnershipVerificationReason.allEvidenceMatchesCurrentUser,
          LegacyOwnershipVerificationOutcome.unknown =>
            LegacyOwnershipVerificationReason.remoteRecordMissing,
          LegacyOwnershipVerificationOutcome.rejected =>
            LegacyOwnershipVerificationReason.metadataMismatchOrOtherOwner,
        },
      );

      expect(result.outcome, outcome);
      expect(
        result.isVerified,
        outcome == LegacyOwnershipVerificationOutcome.verified,
      );
    });
  }
}
