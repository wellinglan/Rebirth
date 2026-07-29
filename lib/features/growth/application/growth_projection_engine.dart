import 'package:rebirth/features/growth/domain/growth_dimension_contributor.dart';
import 'package:rebirth/features/growth/domain/growth_dimension_projection.dart';
import 'package:rebirth/features/growth/domain/growth_projection.dart';
import 'package:rebirth/features/growth/domain/growth_projection_context.dart';
import 'package:rebirth/features/growth/domain/growth_projection_failure.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_aggregation_result.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_privacy.dart';

import 'growth_dimension_contributor_registry.dart';

final class InvalidGrowthProjectionException implements Exception {
  const InvalidGrowthProjectionException(this.reasonCode);

  final String reasonCode;
}

final class GrowthProjectionEngine {
  const GrowthProjectionEngine(this.registry);

  final GrowthDimensionContributorRegistry registry;

  GrowthProjection project(
    PersonalDataAggregationResult result,
    GrowthProjectionContext context,
  ) {
    final dimensions = <GrowthDimensionProjection>[];
    final failures = <GrowthProjectionFailure>[];

    for (final contributor in registry.contributors) {
      try {
        final dimension = contributor.project(result, context);
        _validate(contributor, dimension, context);
        dimensions.add(dimension);
      } on InvalidGrowthProjectionException catch (error) {
        failures.add(
          GrowthProjectionFailure(
            dimensionId: contributor.descriptor.dimensionId,
            reasonCode: error.reasonCode,
            message: '该成长维度返回了无法使用的本地结果。',
          ),
        );
      } catch (_) {
        failures.add(
          GrowthProjectionFailure(
            dimensionId: contributor.descriptor.dimensionId,
            reasonCode: 'contributor_failed',
            message: '该成长维度暂时无法计算，其他维度仍可查看。',
          ),
        );
      }
    }

    return GrowthProjection(
      context: context,
      aggregationResult: result,
      dimensions: dimensions,
      failures: failures,
    );
  }

  void _validate(
    GrowthDimensionContributor contributor,
    GrowthDimensionProjection projection,
    GrowthProjectionContext context,
  ) {
    if (projection.descriptor.dimensionId !=
        contributor.descriptor.dimensionId) {
      throw const InvalidGrowthProjectionException('dimension_id_mismatch');
    }
    if (!projection.sensitivity.isAtLeast(contributor.descriptor.sensitivity)) {
      throw const InvalidGrowthProjectionException('sensitivity_downgrade');
    }
    if (projection.coverage.expectedCount != context.period.days) {
      throw const InvalidGrowthProjectionException('coverage_mismatch');
    }
    final metricIds = <Object>{};
    for (final metric in projection.metrics) {
      if (metric.dimensionId != projection.descriptor.dimensionId) {
        throw const InvalidGrowthProjectionException(
          'metric_dimension_mismatch',
        );
      }
      if (!metricIds.add(metric.metricId)) {
        throw const InvalidGrowthProjectionException('duplicate_metric_id');
      }
      if (metric.coverage.expectedCount != context.period.days) {
        throw const InvalidGrowthProjectionException(
          'metric_coverage_mismatch',
        );
      }
      if (!metric.sensitivity.isAtLeast(projection.sensitivity)) {
        throw const InvalidGrowthProjectionException(
          'metric_sensitivity_downgrade',
        );
      }
    }
  }
}
