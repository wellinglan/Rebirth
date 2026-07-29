import 'dart:collection';

import 'personal_data_contribution.dart';
import 'personal_data_provider_failure.dart';
import 'personal_data_quality.dart';
import 'personal_data_query.dart';

final class PersonalDataAggregationSummary {
  const PersonalDataAggregationSummary({
    required this.providerCount,
    required this.availableProviderCount,
    required this.itemCount,
    required this.quality,
  });

  final int providerCount;
  final int availableProviderCount;
  final int itemCount;
  final PersonalDataQuality quality;
}

final class PersonalDataAggregationResult {
  PersonalDataAggregationResult({
    required this.query,
    required List<PersonalDataContribution> contributions,
    required List<PersonalDataProviderFailure> failures,
    required DateTime generatedAtUtc,
  }) : contributions = UnmodifiableListView(contributions),
       failures = UnmodifiableListView(failures),
       generatedAtUtc = generatedAtUtc,
       summary = _summarize(contributions, failures) {
    if (!generatedAtUtc.isUtc) {
      throw ArgumentError.value(
        generatedAtUtc,
        'generatedAtUtc',
        'Must be UTC.',
      );
    }
  }

  final PersonalDataQuery query;
  final List<PersonalDataContribution> contributions;
  final List<PersonalDataProviderFailure> failures;
  final DateTime generatedAtUtc;
  final PersonalDataAggregationSummary summary;

  bool get isEmpty => contributions.every((entry) => entry.isEmpty);
}

PersonalDataAggregationSummary _summarize(
  List<PersonalDataContribution> contributions,
  List<PersonalDataProviderFailure> failures,
) {
  final quality = failures.isNotEmpty
      ? const PersonalDataQuality.partial('provider_failure')
      : contributions.any(
          (entry) =>
              entry.quality.status == PersonalDataQualityStatus.conflicted,
        )
      ? const PersonalDataQuality.conflicted()
      : contributions.any((entry) => !entry.quality.isComplete)
      ? const PersonalDataQuality.partial('provider_quality_degraded')
      : const PersonalDataQuality.complete();
  return PersonalDataAggregationSummary(
    providerCount: contributions.length + failures.length,
    availableProviderCount: contributions.length,
    itemCount: contributions.fold(
      0,
      (total, contribution) => total + contribution.items.length,
    ),
    quality: quality,
  );
}
