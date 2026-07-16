final class AiDataAuthorization {
  factory AiDataAuthorization({required bool enabled, required int? consentAt}) {
    if ((enabled && consentAt == null) || (consentAt != null && consentAt < 0)) {
      throw ArgumentError('Invalid AI data authorization state.');
    }
    return AiDataAuthorization._(enabled: enabled, consentAt: consentAt);
  }

  const AiDataAuthorization._({required this.enabled, required this.consentAt});

  const AiDataAuthorization.disabled() : enabled = false, consentAt = null;

  final bool enabled;
  final int? consentAt;
}
