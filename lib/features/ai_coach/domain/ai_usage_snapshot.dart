enum AiUsageAvailability { available, disabled, limitReached, unknown }

final class AiUsageSnapshot {
  const AiUsageSnapshot({
    required this.availability,
    required this.enabled,
    required this.dailyLimit,
    required this.used,
    required this.remaining,
    required this.resetsAtUtcMilliseconds,
  });

  const AiUsageSnapshot.unknown()
    : availability = AiUsageAvailability.unknown,
      enabled = false,
      dailyLimit = null,
      used = null,
      remaining = null,
      resetsAtUtcMilliseconds = null;

  final AiUsageAvailability availability;
  final bool enabled;
  final int? dailyLimit;
  final int? used;
  final int? remaining;
  final int? resetsAtUtcMilliseconds;

  bool get preventsGeneration =>
      availability == AiUsageAvailability.disabled ||
      availability == AiUsageAvailability.limitReached;
}
