const int legacyWellbeingScoreScale = 5;
const int currentWellbeingScoreScale = 10;
const int wellbeingDescriptionMaxLength = 80;

int? normalizeWellbeingScore(int? score, int? scale) {
  if (score == null) return null;
  final effectiveScale = scale ?? legacyWellbeingScoreScale;
  if (effectiveScale == legacyWellbeingScoreScale) {
    if (score < 1 || score > legacyWellbeingScoreScale) {
      throw StateError('Invalid legacy wellbeing score: $score.');
    }
    return score * 2;
  }
  if (effectiveScale == currentWellbeingScoreScale) {
    if (score < 1 || score > currentWellbeingScoreScale) {
      throw StateError('Invalid wellbeing score: $score.');
    }
    return score;
  }
  throw StateError('Unsupported wellbeing score scale: $effectiveScale.');
}

String? normalizeWellbeingDescription(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized.length > wellbeingDescriptionMaxLength) {
    throw ArgumentError.value(
      value,
      'description',
      'Description must not exceed $wellbeingDescriptionMaxLength characters.',
    );
  }
  return normalized;
}
