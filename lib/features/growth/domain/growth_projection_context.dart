import 'package:rebirth/features/personal_data/domain/personal_data_time_range.dart';

import 'growth_period.dart';

final class GrowthProjectionContext {
  GrowthProjectionContext({
    required this.period,
    required this.timeRange,
    required List<String> expectedLocalDates,
    required this.generatedAtUtc,
  }) : expectedLocalDates = List.unmodifiable(expectedLocalDates) {
    if (!generatedAtUtc.isUtc) {
      throw ArgumentError.value(
        generatedAtUtc,
        'generatedAtUtc',
        'Must be UTC.',
      );
    }
    if (this.expectedLocalDates.length != period.days ||
        this.expectedLocalDates.first != timeRange.startLocalDate ||
        this.expectedLocalDates.last != timeRange.endLocalDateInclusive) {
      throw ArgumentError(
        'Expected dates must exactly cover the Growth period.',
      );
    }
  }

  final GrowthPeriod period;
  final PersonalDataTimeRange timeRange;
  final List<String> expectedLocalDates;
  final DateTime generatedAtUtc;
}
