import 'package:rebirth/features/growth/domain/growth_coverage.dart';
import 'package:rebirth/features/growth/domain/growth_evidence.dart';
import 'package:rebirth/features/growth/domain/growth_identifier.dart';
import 'package:rebirth/features/growth/domain/growth_metric_projection.dart';
import 'package:rebirth/features/growth/domain/growth_projection_context.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_aggregation_result.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_capability.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_contribution.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_fact.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_identifier.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_item.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_privacy.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_quality.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_value.dart';

final class GrowthFactObservation {
  const GrowthFactObservation({
    required this.providerId,
    required this.item,
    required this.fact,
  });

  final PersonalDataProviderId providerId;
  final PersonalDataItem item;
  final PersonalDataFact fact;
}

PersonalDataContribution? contributionFor(
  PersonalDataAggregationResult result,
  PersonalDataProviderId providerId,
) {
  for (final contribution in result.contributions) {
    if (contribution.providerId == providerId) return contribution;
  }
  return null;
}

List<GrowthFactObservation> observationsFor(
  PersonalDataAggregationResult result, {
  required PersonalDataProviderId providerId,
  required PersonalDataFactKey factKey,
}) {
  final contribution = contributionFor(result, providerId);
  if (contribution == null) return const [];
  return [
    for (final item in contribution.items)
      for (final fact in item.facts)
        if (fact.key == factKey)
          GrowthFactObservation(providerId: providerId, item: item, fact: fact),
  ];
}

GrowthMetricProjection projectMetric({
  required PersonalDataAggregationResult result,
  required GrowthProjectionContext context,
  required PersonalDataProviderId providerId,
  required PersonalDataFactKey factKey,
  required GrowthMetricId metricId,
  required GrowthDimensionId dimensionId,
  required String displayName,
  required String definition,
  required Set<PersonalDataCapability> sourceCapabilities,
  required PersonalDataSensitivity minimumSensitivity,
  required PersonalDataValue? Function(List<PersonalDataValue> values)
  summarize,
  String? unit,
  int displayOrder = 100,
}) {
  final contribution = contributionFor(result, providerId);
  final observations = observationsFor(
    result,
    providerId: providerId,
    factKey: factKey,
  );
  final byDate = <String, GrowthFactObservation>{
    for (final observation in observations)
      if (observation.item.localDate != null)
        observation.item.localDate!: observation,
  };
  final values = <PersonalDataValue>[
    for (final date in context.expectedLocalDates)
      if (byDate[date] case final observation?) observation.fact.value,
  ];
  final coverage = GrowthCoverage.fromObserved(
    observedCount: values.length,
    expectedCount: context.period.days,
  );
  final sensitivity = observations.fold<PersonalDataSensitivity>(
    contribution?.sensitivity ?? minimumSensitivity,
    (current, observation) => current
        .elevatedWith(observation.item.sensitivity)
        .elevatedWith(observation.fact.sensitivity),
  );

  return GrowthMetricProjection(
    metricId: metricId,
    dimensionId: dimensionId,
    displayName: displayName,
    timeRange: context.timeRange,
    value: summarize(values),
    series: [
      for (final date in context.expectedLocalDates)
        GrowthMetricPoint(localDate: date, value: byDate[date]?.fact.value),
    ],
    unit: unit,
    coverage: coverage,
    quality: metricQuality(
      result: result,
      providerId: providerId,
      contribution: contribution,
      observations: observations,
      coverage: coverage,
    ),
    sensitivity: sensitivity,
    sourceProviderIds: {providerId},
    sourceCapabilities: sourceCapabilities,
    evidence: [
      for (final observation in observations)
        GrowthEvidence(
          providerId: providerId,
          itemId: observation.item.id,
          factKey: observation.fact.key,
          localDate: observation.item.localDate,
          quality: observation.item.quality,
          sensitivity: observation.fact.sensitivity,
        ),
    ],
    definition: definition,
    generatedAtUtc: context.generatedAtUtc,
    displayOrder: displayOrder,
  );
}

PersonalDataQuality metricQuality({
  required PersonalDataAggregationResult result,
  required PersonalDataProviderId providerId,
  required PersonalDataContribution? contribution,
  required List<GrowthFactObservation> observations,
  required GrowthCoverage coverage,
}) {
  if (contribution == null) {
    final failed = result.failures.any(
      (failure) => failure.providerId == providerId,
    );
    return failed
        ? const PersonalDataQuality.unavailable('provider_failure')
        : const PersonalDataQuality.partial('provider_not_selected');
  }
  if (contribution.quality.status == PersonalDataQualityStatus.conflicted ||
      observations.any(
        (observation) =>
            observation.item.quality.status ==
            PersonalDataQualityStatus.conflicted,
      )) {
    return const PersonalDataQuality.conflicted();
  }
  if (contribution.quality.status == PersonalDataQualityStatus.stale) {
    return const PersonalDataQuality.stale('provider_stale');
  }
  if (!contribution.quality.isComplete) {
    return const PersonalDataQuality.partial('provider_quality_degraded');
  }
  if (coverage.missingCount > 0) {
    return const PersonalDataQuality.partial('missing_observations');
  }
  return const PersonalDataQuality.complete();
}

PersonalDataQuality dimensionQuality(Iterable<GrowthMetricProjection> metrics) {
  final values = metrics.toList(growable: false);
  if (values.any(
    (metric) => metric.quality.status == PersonalDataQualityStatus.conflicted,
  )) {
    return const PersonalDataQuality.conflicted();
  }
  if (values.every((metric) => metric.quality.isUnavailable)) {
    return const PersonalDataQuality.unavailable('source_unavailable');
  }
  if (values.any((metric) => !metric.quality.isComplete)) {
    return const PersonalDataQuality.partial('metric_quality_degraded');
  }
  return const PersonalDataQuality.complete();
}

GrowthCoverage dimensionCoverage(
  Iterable<GrowthMetricProjection> metrics,
  int expectedCount,
) {
  final observedDates = <String>{};
  for (final metric in metrics) {
    for (final point in metric.series) {
      if (point.value != null) observedDates.add(point.localDate);
    }
  }
  return GrowthCoverage.fromObserved(
    observedCount: observedDates.length,
    expectedCount: expectedCount,
  );
}

PersonalDataValue? sumDurations(List<PersonalDataValue> values) {
  if (values.isEmpty) return null;
  return PersonalDataDurationValue(
    minutes: values.whereType<PersonalDataDurationValue>().fold(
      0,
      (total, value) => total + value.minutes,
    ),
  );
}

PersonalDataValue? averageScores(List<PersonalDataValue> values) {
  final scores = values.whereType<PersonalDataScoreValue>().toList();
  if (scores.isEmpty) return null;
  return PersonalDataDecimalValue(
    scores.fold(0.0, (total, value) => total + value.value) / scores.length,
  );
}

PersonalDataValue? countObserved(List<PersonalDataValue> values) =>
    PersonalDataCountValue(values.length);
