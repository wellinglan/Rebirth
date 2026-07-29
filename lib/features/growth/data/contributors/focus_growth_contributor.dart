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

final class FocusGrowthContributor implements GrowthDimensionContributor {
  FocusGrowthContributor();

  static final _providerId = PersonalDataProviderId('rebirth.today');
  static final _capabilities = {PersonalDataCapability.dailyState};

  @override
  final descriptor = GrowthDimensionDescriptor(
    dimensionId: GrowthDimensions.focus,
    displayName: '专注投入',
    description: '科研与学习投入的原始时间记录',
    requiredCapabilities: _capabilities,
    sensitivity: PersonalDataSensitivity.standardPrivate,
    displayOrder: 10,
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
        factKey: PersonalDataFactKey('today.research_duration'),
        metricId: GrowthMetrics.researchDuration,
        dimensionId: descriptor.dimensionId,
        displayName: '科研时间',
        definition: '所选周期内用户主动填写的科研时间原始分钟数与总量。',
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
        factKey: PersonalDataFactKey('today.learning_duration'),
        metricId: GrowthMetrics.learningDuration,
        dimensionId: descriptor.dimensionId,
        displayName: '学习时间',
        definition: '所选周期内用户主动填写的学习时间原始分钟数与总量。',
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
