import 'package:rebirth/features/growth/domain/growth_builtin_ids.dart';
import 'package:rebirth/features/growth/domain/growth_dimension_contributor.dart';
import 'package:rebirth/features/growth/domain/growth_dimension_descriptor.dart';
import 'package:rebirth/features/growth/domain/growth_dimension_projection.dart';
import 'package:rebirth/features/growth/domain/growth_projection_context.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_aggregation_result.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_capability.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_identifier.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_privacy.dart';

import 'growth_contributor_support.dart';

final class RecoveryGrowthContributor implements GrowthDimensionContributor {
  RecoveryGrowthContributor();

  static final _providerId = PersonalDataProviderId('rebirth.health');
  static final _capabilities = {PersonalDataCapability.wellbeingMetrics};

  @override
  final descriptor = GrowthDimensionDescriptor(
    dimensionId: GrowthDimensions.recovery,
    displayName: '身体恢复',
    description: '睡眠与运动的原始时间记录，不包含医疗判断',
    requiredCapabilities: _capabilities,
    sensitivity: PersonalDataSensitivity.highlySensitive,
    displayOrder: 20,
  );

  @override
  Set<PersonalDataCapability> get requiredCapabilities => _capabilities;

  @override
  GrowthDimensionProjection project(
    PersonalDataAggregationResult result,
    GrowthProjectionContext context,
  ) {
    final metrics = [
      projectMetric(
        result: result,
        context: context,
        providerId: _providerId,
        factKey: PersonalDataFactKey('health.sleep_duration'),
        metricId: GrowthMetrics.sleepDuration,
        dimensionId: descriptor.dimensionId,
        displayName: '睡眠时间',
        definition: '所选周期内用户主动填写的睡眠时间原始分钟数与总量。',
        sourceCapabilities: _capabilities,
        minimumSensitivity: descriptor.sensitivity,
        summarize: sumDurations,
        unit: '分钟',
        displayOrder: 10,
      ),
      projectMetric(
        result: result,
        context: context,
        providerId: _providerId,
        factKey: PersonalDataFactKey('health.exercise_duration'),
        metricId: GrowthMetrics.exerciseDuration,
        dimensionId: descriptor.dimensionId,
        displayName: '运动时间',
        definition: '所选周期内用户主动填写的运动时间原始分钟数与总量。',
        sourceCapabilities: _capabilities,
        minimumSensitivity: descriptor.sensitivity,
        summarize: sumDurations,
        unit: '分钟',
        displayOrder: 20,
      ),
    ];
    return GrowthDimensionProjection(
      descriptor: descriptor,
      metrics: metrics,
      coverage: dimensionCoverage(metrics, context.period.days),
      quality: dimensionQuality(metrics),
      sensitivity: descriptor.sensitivity,
    );
  }
}
