import '../domain/personal_data_aggregation_result.dart';
import '../domain/personal_data_contribution.dart';
import '../domain/personal_data_fact.dart';
import '../domain/personal_data_item.dart';
import '../domain/personal_data_provider.dart';
import '../domain/personal_data_provider_failure.dart';
import '../domain/personal_data_privacy.dart';
import '../domain/personal_data_query.dart';
import 'personal_data_provider_registry.dart';

final class InvalidPersonalDataContributionException implements Exception {
  const InvalidPersonalDataContributionException(this.reasonCode);

  final String reasonCode;
}

final class PersonalDataAggregationEngine {
  const PersonalDataAggregationEngine(this.registry);

  final PersonalDataProviderRegistry registry;

  Future<PersonalDataAggregationResult> aggregate(
    PersonalDataQuery query,
  ) async {
    final contributions = <PersonalDataContribution>[];
    final failures = <PersonalDataProviderFailure>[];

    // Stable sequential reads avoid sharing a Drift connection across
    // concurrent feature queries while preserving provider isolation.
    for (final provider in registry.select(query)) {
      try {
        final contribution = await provider.collect(query);
        _validate(provider, contribution, query);
        contributions.add(contribution);
      } on InvalidPersonalDataContributionException catch (error) {
        failures.add(
          PersonalDataProviderFailure(
            providerId: provider.descriptor.providerId,
            reasonCode: error.reasonCode,
            message: '该数据来源返回了无法使用的本地结果。',
          ),
        );
      } catch (_) {
        failures.add(
          PersonalDataProviderFailure(
            providerId: provider.descriptor.providerId,
            reasonCode: 'provider_read_failed',
            message: '该数据来源暂时不可用，请稍后重试。',
          ),
        );
      }
    }

    return PersonalDataAggregationResult(
      query: query,
      contributions: contributions,
      failures: failures,
      generatedAtUtc: query.requestedAtUtc,
    );
  }

  void _validate(
    PersonalDataProvider provider,
    PersonalDataContribution contribution,
    PersonalDataQuery query,
  ) {
    final descriptor = provider.descriptor;
    if (contribution.providerId != descriptor.providerId) {
      throw const InvalidPersonalDataContributionException(
        'provider_id_mismatch',
      );
    }
    if (contribution.providerSchemaVersion !=
        descriptor.providerSchemaVersion) {
      throw const InvalidPersonalDataContributionException(
        'provider_schema_mismatch',
      );
    }
    if (!descriptor.capabilities.containsAll(contribution.capabilities)) {
      throw const InvalidPersonalDataContributionException(
        'undeclared_capability',
      );
    }
    if (!_sameRange(contribution, query)) {
      throw const InvalidPersonalDataContributionException(
        'covered_range_mismatch',
      );
    }
    if (!contribution.sensitivity.isAtLeast(descriptor.defaultSensitivity)) {
      throw const InvalidPersonalDataContributionException(
        'sensitivity_downgrade',
      );
    }
    if (contribution.items.length > query.maxItemsPerProvider) {
      throw const InvalidPersonalDataContributionException(
        'result_limit_exceeded',
      );
    }

    final itemIds = <Object>{};
    for (final item in contribution.items) {
      if (!itemIds.add(item.id)) {
        throw const InvalidPersonalDataContributionException(
          'duplicate_item_id',
        );
      }
      _validateItem(item, descriptor.defaultSensitivity);
    }
    _validateFacts(contribution.summaryFacts, descriptor.defaultSensitivity);
  }

  bool _sameRange(
    PersonalDataContribution contribution,
    PersonalDataQuery query,
  ) {
    final actual = contribution.coveredTimeRange;
    final expected = query.timeRange;
    return actual.startInclusiveUtc == expected.startInclusiveUtc &&
        actual.endExclusiveUtc == expected.endExclusiveUtc &&
        actual.startLocalDate == expected.startLocalDate &&
        actual.endLocalDateInclusive == expected.endLocalDateInclusive;
  }

  void _validateItem(
    PersonalDataItem item,
    PersonalDataSensitivity minimumSensitivity,
  ) {
    if (!item.sensitivity.isAtLeast(minimumSensitivity)) {
      throw const InvalidPersonalDataContributionException(
        'item_sensitivity_downgrade',
      );
    }
    _validateFacts(item.facts, minimumSensitivity);
  }

  void _validateFacts(
    List<PersonalDataFact> facts,
    PersonalDataSensitivity minimumSensitivity,
  ) {
    final keys = <Object>{};
    for (final fact in facts) {
      if (!keys.add(fact.key)) {
        throw const InvalidPersonalDataContributionException(
          'duplicate_fact_key',
        );
      }
      if (!fact.sensitivity.isAtLeast(minimumSensitivity)) {
        throw const InvalidPersonalDataContributionException(
          'fact_sensitivity_downgrade',
        );
      }
    }
  }
}
