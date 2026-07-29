import 'dart:collection';

import 'package:rebirth/features/personal_data/domain/personal_data_capability.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_identifier.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_privacy.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_quality.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_time_range.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_value.dart';

import 'growth_coverage.dart';
import 'growth_evidence.dart';
import 'growth_identifier.dart';

final class GrowthMetricPoint {
  const GrowthMetricPoint({required this.localDate, required this.value});

  final String localDate;
  final PersonalDataValue? value;
}

final class GrowthMetricProjection
    implements Comparable<GrowthMetricProjection> {
  GrowthMetricProjection({
    required this.metricId,
    required this.dimensionId,
    required String displayName,
    required this.timeRange,
    required this.value,
    required List<GrowthMetricPoint> series,
    required this.unit,
    required this.coverage,
    required this.quality,
    required this.sensitivity,
    required Set<PersonalDataProviderId> sourceProviderIds,
    required Set<PersonalDataCapability> sourceCapabilities,
    required List<GrowthEvidence> evidence,
    required String definition,
    required this.generatedAtUtc,
    this.displayOrder = 100,
  }) : displayName = _requireMetricText(displayName, 'displayName'),
       series = UnmodifiableListView(series),
       sourceProviderIds = UnmodifiableSetView(Set.of(sourceProviderIds)),
       sourceCapabilities = UnmodifiableSetView(sourceCapabilities),
       evidence = UnmodifiableListView(
         List<GrowthEvidence>.of(evidence)..sort(),
       ),
       definition = _requireMetricText(definition, 'definition') {
    if (!generatedAtUtc.isUtc) {
      throw ArgumentError.value(
        generatedAtUtc,
        'generatedAtUtc',
        'Must be UTC.',
      );
    }
    if (this.series.length != coverage.expectedCount) {
      throw ArgumentError('Metric series must match expected coverage.');
    }
  }

  final GrowthMetricId metricId;
  final GrowthDimensionId dimensionId;
  final String displayName;
  final PersonalDataTimeRange timeRange;
  final PersonalDataValue? value;
  final List<GrowthMetricPoint> series;
  final String? unit;
  final GrowthCoverage coverage;
  final PersonalDataQuality quality;
  final PersonalDataSensitivity sensitivity;
  final Set<PersonalDataProviderId> sourceProviderIds;
  final Set<PersonalDataCapability> sourceCapabilities;
  final List<GrowthEvidence> evidence;
  final String definition;
  final DateTime generatedAtUtc;
  final int displayOrder;

  @override
  int compareTo(GrowthMetricProjection other) {
    final order = displayOrder.compareTo(other.displayOrder);
    return order != 0 ? order : metricId.compareTo(other.metricId);
  }
}

String _requireMetricText(String value, String name) {
  final result = value.trim();
  if (result.isEmpty || result.length > 240) {
    throw ArgumentError.value(value, name, 'Must be 1-240 characters.');
  }
  return result;
}
