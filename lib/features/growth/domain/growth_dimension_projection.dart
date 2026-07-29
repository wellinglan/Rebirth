import 'dart:collection';

import 'package:rebirth/features/personal_data/domain/personal_data_privacy.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_quality.dart';

import 'growth_coverage.dart';
import 'growth_dimension_descriptor.dart';
import 'growth_metric_projection.dart';

final class GrowthDimensionProjection
    implements Comparable<GrowthDimensionProjection> {
  GrowthDimensionProjection({
    required this.descriptor,
    required List<GrowthMetricProjection> metrics,
    required this.coverage,
    required this.quality,
    required this.sensitivity,
  }) : metrics = UnmodifiableListView(
         List<GrowthMetricProjection>.of(metrics)..sort(),
       );

  final GrowthDimensionDescriptor descriptor;
  final List<GrowthMetricProjection> metrics;
  final GrowthCoverage coverage;
  final PersonalDataQuality quality;
  final PersonalDataSensitivity sensitivity;

  @override
  int compareTo(GrowthDimensionProjection other) =>
      descriptor.compareTo(other.descriptor);
}
