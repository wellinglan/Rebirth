import 'package:rebirth/features/growth/domain/growth_builtin_ids.dart';
import 'package:rebirth/features/growth/domain/growth_coverage.dart';
import 'package:rebirth/features/growth/domain/growth_dimension_contributor.dart';
import 'package:rebirth/features/growth/domain/growth_dimension_descriptor.dart';
import 'package:rebirth/features/growth/domain/growth_dimension_projection.dart';
import 'package:rebirth/features/growth/domain/growth_evidence.dart';
import 'package:rebirth/features/growth/domain/growth_metric_projection.dart';
import 'package:rebirth/features/growth/domain/growth_projection_context.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_aggregation_result.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_capability.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_identifier.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_privacy.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_value.dart';

import 'growth_contributor_support.dart';

final class ReflectionGrowthContributor implements GrowthDimensionContributor {
  ReflectionGrowthContributor();

  static final _providerId = PersonalDataProviderId('rebirth.journal');
  static final _statusKey = PersonalDataFactKey('journal.entry_status');
  static final _capabilities = {PersonalDataCapability.reflection};

  @override
  final descriptor = GrowthDimensionDescriptor(
    dimensionId: GrowthDimensions.reflection,
    displayName: '反思习惯',
    description: 'Journal 的未记录、草稿与已完成状态',
    requiredCapabilities: _capabilities,
    sensitivity: PersonalDataSensitivity.sensitive,
    displayOrder: 40,
  );

  @override
  Set<PersonalDataCapability> get requiredCapabilities => _capabilities;

  @override
  GrowthDimensionProjection project(
    PersonalDataAggregationResult result,
    GrowthProjectionContext context,
  ) {
    final contribution = contributionFor(result, _providerId);
    final observations = observationsFor(
      result,
      providerId: _providerId,
      factKey: _statusKey,
    );
    final byDate = {
      for (final observation in observations)
        if (observation.item.localDate != null)
          observation.item.localDate!: observation,
    };
    final coverage = GrowthCoverage.fromObserved(
      observedCount: byDate.length,
      expectedCount: context.period.days,
    );
    final quality = metricQuality(
      result: result,
      providerId: _providerId,
      contribution: contribution,
      observations: observations,
      coverage: coverage,
    );
    final metric = GrowthMetricProjection(
      metricId: GrowthMetrics.reflectionStatus,
      dimensionId: descriptor.dimensionId,
      displayName: '复盘状态',
      timeRange: context.timeRange,
      value: PersonalDataCountValue(byDate.length),
      series: [
        for (final date in context.expectedLocalDates)
          GrowthMetricPoint(
            localDate: date,
            value:
                byDate[date]?.fact.value ??
                PersonalDataCategoricalValue('missing'),
          ),
      ],
      unit: '天',
      coverage: coverage,
      quality: quality,
      sensitivity: descriptor.sensitivity,
      sourceProviderIds: {_providerId},
      sourceCapabilities: _capabilities,
      evidence: [
        for (final observation in observations)
          GrowthEvidence(
            providerId: _providerId,
            itemId: observation.item.id,
            factKey: observation.fact.key,
            localDate: observation.item.localDate,
            quality: observation.item.quality,
            sensitivity: observation.fact.sensitivity,
          ),
      ],
      definition: '按本地自然日区分未记录、草稿和已完成，不读取 Journal 正文。',
      generatedAtUtc: context.generatedAtUtc,
    );
    return GrowthDimensionProjection(
      descriptor: descriptor,
      metrics: [metric],
      coverage: coverage,
      quality: quality,
      sensitivity: descriptor.sensitivity,
    );
  }
}
