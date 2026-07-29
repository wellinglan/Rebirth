enum PersonalDataQualityStatus {
  complete,
  partial,
  unavailable,
  unsupported,
  conflicted,
  stale,
}

final class PersonalDataQuality {
  const PersonalDataQuality(this.status, {this.reasonCode});

  const PersonalDataQuality.complete()
    : this(PersonalDataQualityStatus.complete);

  const PersonalDataQuality.partial(String reasonCode)
    : this(PersonalDataQualityStatus.partial, reasonCode: reasonCode);

  const PersonalDataQuality.unavailable(String reasonCode)
    : this(PersonalDataQualityStatus.unavailable, reasonCode: reasonCode);

  const PersonalDataQuality.unsupported(String reasonCode)
    : this(PersonalDataQualityStatus.unsupported, reasonCode: reasonCode);

  const PersonalDataQuality.conflicted()
    : this(
        PersonalDataQualityStatus.conflicted,
        reasonCode: 'sync_conflict_present',
      );

  const PersonalDataQuality.stale(String reasonCode)
    : this(PersonalDataQualityStatus.stale, reasonCode: reasonCode);

  final PersonalDataQualityStatus status;
  final String? reasonCode;

  bool get isComplete => status == PersonalDataQualityStatus.complete;
  bool get isUnavailable =>
      status == PersonalDataQualityStatus.unavailable ||
      status == PersonalDataQualityStatus.unsupported;
}
