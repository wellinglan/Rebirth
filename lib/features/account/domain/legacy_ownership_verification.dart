enum LegacyOwnershipVerificationOutcome {
  verified('verified'),
  unknown('unknown'),
  rejected('rejected');

  const LegacyOwnershipVerificationOutcome(this.wireValue);

  final String wireValue;

  static LegacyOwnershipVerificationOutcome fromWire(String value) {
    return values.firstWhere(
      (candidate) => candidate.wireValue == value,
      orElse: () => throw const FormatException(
        'Unknown ownership verification outcome.',
      ),
    );
  }
}

enum LegacyOwnershipVerificationReason {
  allEvidenceMatchesCurrentUser('all_evidence_matches_current_user'),
  noVerifiableEvidence('no_verifiable_evidence'),
  remoteRecordMissing('remote_record_missing'),
  metadataMismatchOrOtherOwner('metadata_mismatch_or_other_owner');

  const LegacyOwnershipVerificationReason(this.wireValue);

  final String wireValue;

  static LegacyOwnershipVerificationReason fromWire(String value) {
    return values.firstWhere(
      (candidate) => candidate.wireValue == value,
      orElse: () =>
          throw const FormatException('Unknown ownership verification reason.'),
    );
  }
}

final class LegacyOwnershipEvidence {
  const LegacyOwnershipEvidence({
    required this.tableName,
    required this.recordId,
    required this.serverVersion,
    required this.metadataFingerprint,
  });

  final String tableName;
  final String recordId;
  final int serverVersion;
  final String metadataFingerprint;
}

final class LegacyOwnershipVerificationResult {
  const LegacyOwnershipVerificationResult({
    required this.outcome,
    required this.verifiedCount,
    required this.rejectedCount,
    required this.unknownCount,
    required this.reason,
  });

  final LegacyOwnershipVerificationOutcome outcome;
  final int verifiedCount;
  final int rejectedCount;
  final int unknownCount;
  final LegacyOwnershipVerificationReason reason;

  bool get isVerified => outcome == LegacyOwnershipVerificationOutcome.verified;
}
