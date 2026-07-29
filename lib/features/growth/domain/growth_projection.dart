import 'dart:collection';

import 'package:rebirth/features/personal_data/domain/personal_data_aggregation_result.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_quality.dart';

import 'growth_dimension_projection.dart';
import 'growth_projection_context.dart';
import 'growth_projection_failure.dart';

final class GrowthProjection {
  GrowthProjection({
    required this.context,
    required this.aggregationResult,
    required List<GrowthDimensionProjection> dimensions,
    required List<GrowthProjectionFailure> failures,
  }) : dimensions = UnmodifiableListView(
         List<GrowthDimensionProjection>.of(dimensions)..sort(),
       ),
       failures = UnmodifiableListView(failures),
       quality = _quality(dimensions, failures);

  final GrowthProjectionContext context;
  final PersonalDataAggregationResult aggregationResult;
  final List<GrowthDimensionProjection> dimensions;
  final List<GrowthProjectionFailure> failures;
  final PersonalDataQuality quality;

  bool get isEmpty => dimensions.every(
    (dimension) =>
        dimension.metrics.every((metric) => metric.coverage.observedCount == 0),
  );
}

PersonalDataQuality _quality(
  List<GrowthDimensionProjection> dimensions,
  List<GrowthProjectionFailure> failures,
) {
  if (failures.isNotEmpty) {
    return const PersonalDataQuality.partial('contributor_failure');
  }
  if (dimensions.any(
    (dimension) =>
        dimension.quality.status == PersonalDataQualityStatus.conflicted,
  )) {
    return const PersonalDataQuality.conflicted();
  }
  if (dimensions.any((dimension) => !dimension.quality.isComplete)) {
    return const PersonalDataQuality.partial('dimension_quality_degraded');
  }
  return const PersonalDataQuality.complete();
}
