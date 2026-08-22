enum AiUsageAvailability { available, disabled, limitReached, unknown }

enum AiUsageUnit { requests, tokens }

enum AiUsageScope { chat, reports }

final class AiUsageSnapshot {
  const AiUsageSnapshot({
    required this.availability,
    required this.enabled,
    required this.dailyLimit,
    required this.used,
    required this.remaining,
    required this.resetsAtUtcMilliseconds,
    this.reserved = 0,
    this.unit = AiUsageUnit.requests,
  });

  const AiUsageSnapshot.unknown()
    : availability = AiUsageAvailability.unknown,
      enabled = false,
      dailyLimit = null,
      used = null,
      remaining = null,
      resetsAtUtcMilliseconds = null,
      reserved = null,
      unit = AiUsageUnit.tokens;

  final AiUsageAvailability availability;
  final bool enabled;
  final int? dailyLimit;
  final int? used;
  final int? remaining;
  final int? resetsAtUtcMilliseconds;
  final int? reserved;
  final AiUsageUnit unit;

  bool get preventsGeneration =>
      availability == AiUsageAvailability.disabled ||
      availability == AiUsageAvailability.limitReached;
}
