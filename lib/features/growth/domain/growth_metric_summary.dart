final class GrowthMetricSummary {
  const GrowthMetricSummary({
    required this.recordedDayCount,
    required this.total,
    required this.average,
    required this.minimum,
    required this.maximum,
  });

  factory GrowthMetricSummary.fromValues(Iterable<int?> values) {
    var recordedDayCount = 0;
    var total = 0;
    int? minimum;
    int? maximum;

    for (final value in values) {
      if (value == null) {
        continue;
      }

      recordedDayCount += 1;
      total += value;
      minimum = minimum == null || value < minimum ? value : minimum;
      maximum = maximum == null || value > maximum ? value : maximum;
    }

    return GrowthMetricSummary(
      recordedDayCount: recordedDayCount,
      total: total,
      average: recordedDayCount == 0 ? null : total / recordedDayCount,
      minimum: minimum,
      maximum: maximum,
    );
  }

  final int recordedDayCount;
  final int total;
  final double? average;
  final int? minimum;
  final int? maximum;
}
