final class GrowthCoverage {
  const GrowthCoverage({
    required this.observedCount,
    required this.expectedCount,
    required this.missingCount,
  }) : assert(observedCount >= 0),
       assert(expectedCount >= 0),
       assert(missingCount >= 0),
       assert(observedCount + missingCount == expectedCount);

  factory GrowthCoverage.fromObserved({
    required int observedCount,
    required int expectedCount,
  }) {
    if (observedCount < 0 ||
        expectedCount < 0 ||
        observedCount > expectedCount) {
      throw ArgumentError('Growth coverage counts are inconsistent.');
    }
    return GrowthCoverage(
      observedCount: observedCount,
      expectedCount: expectedCount,
      missingCount: expectedCount - observedCount,
    );
  }

  final int observedCount;
  final int expectedCount;
  final int missingCount;

  double get percentage =>
      expectedCount == 0 ? 0 : observedCount * 100 / expectedCount;
}
