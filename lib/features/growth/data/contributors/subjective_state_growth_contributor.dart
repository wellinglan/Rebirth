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

final class SubjectiveStateGrowthContributor
    implements GrowthDimensionContributor {
  SubjectiveStateGrowthContributor();

  static final _providerId = PersonalDataProviderId('rebirth.today');
  static final _capabilities = {PersonalDataCapability.dailyState};

  @override
  final descriptor = GrowthDimensionDescriptor(
    dimensionId: GrowthDimensions.subjectiveState,
    displayName: '主观状态',
    description: 'Mood 与 Energy 的原始自评记录，不进行心理判断',
    requiredCapabilities: _capabilities,
    sensitivity: PersonalDataSensitivity.standardPrivate,
    displayOrder: 30,
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
        factKey: PersonalDataFactKey('today.mood_score'),
        metricId: GrowthMetrics.moodScore,
        dimensionId: descriptor.dimensionId,
        displayName: 'Mood',
        definition: '所选周期内用户主动记录的 Mood 评分与平均值。',
        sourceCapabilities: _capabilities,
        minimumSensitivity: descriptor.sensitivity,
        summarize: averageScores,
        unit: '1-10',
        displayOrder: 10,
      ),
      projectMetric(
        result: result,
        context: context,
        providerId: _providerId,
        factKey: PersonalDataFactKey('today.energy_score'),
        metricId: GrowthMetrics.energyScore,
        dimensionId: descriptor.dimensionId,
        displayName: 'Energy',
        definition: '所选周期内用户主动记录的 Energy 评分与平均值。',
        sourceCapabilities: _capabilities,
        minimumSensitivity: descriptor.sensitivity,
        summarize: averageScores,
        unit: '1-10',
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
