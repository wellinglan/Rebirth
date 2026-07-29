import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/personal_data/application/personal_data_aggregation_engine.dart';
import 'package:rebirth/features/personal_data/application/personal_data_provider_registry.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_capability.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_contribution.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_fact.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_identifier.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_item.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_privacy.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_provider.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_provider_descriptor.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_quality.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_query.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_value.dart';

void main() {
  final query = PersonalDataQuery.daily(
    localDate: '2026-07-29',
    requestedAtUtc: DateTime.utc(2026, 7, 29, 3),
  );

  group('PersonalDataProviderRegistry', () {
    test('rejects duplicate IDs and returns stable display order', () {
      final later = _provider('future.later', displayOrder: 20);
      final earlier = _provider('future.earlier', displayOrder: 10);
      final registry = PersonalDataProviderRegistry([later, earlier]);

      expect(
        registry.providers.map((entry) => entry.descriptor.providerId.value),
        ['future.earlier', 'future.later'],
      );
      expect(
        () => PersonalDataProviderRegistry([
          earlier,
          _provider('future.earlier'),
        ]),
        throwsA(isA<DuplicatePersonalDataProviderException>()),
      );
    });

    test('selects by provider and custom capability without core changes', () {
      final growthCapability = PersonalDataCapability('future.growth_progress');
      final growth = _provider(
        'future.growth',
        capabilities: {growthCapability},
      );
      final other = _provider('future.reading');
      final registry = PersonalDataProviderRegistry([other, growth]);
      final filtered = PersonalDataQuery(
        timeRange: query.timeRange,
        localTimeContext: query.localTimeContext,
        requestedAtUtc: query.requestedAtUtc,
        requestedCapabilities: {growthCapability},
      );

      expect(registry.select(filtered), [growth]);
      expect(registry.providersForCapability(growthCapability), [growth]);
      expect(
        registry.providerById(PersonalDataProviderId('future.growth')),
        growth,
      );
    });

    test('empty registry is immutable and safe', () {
      final registry = PersonalDataProviderRegistry(const []);
      expect(registry.select(query), isEmpty);
      expect(
        () => registry.providers.add(_provider('future.growth')),
        throwsUnsupportedError,
      );
    });
  });

  group('PersonalDataAggregationEngine', () {
    test('aggregates five providers in deterministic registry order', () async {
      final providers = [
        _provider('rebirth.health', displayOrder: 50),
        _provider('rebirth.profile', displayOrder: 10),
        _provider('rebirth.journal', displayOrder: 40),
        _provider('rebirth.today', displayOrder: 30),
        _provider('rebirth.plan', displayOrder: 20),
      ];
      final result = await PersonalDataAggregationEngine(
        PersonalDataProviderRegistry(providers),
      ).aggregate(query);

      expect(result.contributions.map((entry) => entry.providerId.value), [
        'rebirth.profile',
        'rebirth.plan',
        'rebirth.today',
        'rebirth.journal',
        'rebirth.health',
      ]);
      expect(result.failures, isEmpty);
      expect(result.generatedAtUtc, query.requestedAtUtc);
    });

    test('isolates one provider exception and keeps other data', () async {
      final healthy = _provider('future.healthy');
      final failed = _provider(
        'future.failed',
        collect: (_) => throw StateError('private body must not escape'),
      );
      final result = await PersonalDataAggregationEngine(
        PersonalDataProviderRegistry([failed, healthy]),
      ).aggregate(query);

      expect(result.contributions, hasLength(1));
      expect(result.failures, hasLength(1));
      expect(result.failures.single.reasonCode, 'provider_read_failed');
      expect(result.failures.single.message, isNot(contains('private body')));
      expect(result.summary.quality.status, PersonalDataQualityStatus.partial);
    });

    test('invalid provider response becomes a privacy-safe failure', () async {
      final provider = _provider(
        'future.invalid',
        collect: (query) async => _contribution(
          providerId: PersonalDataProviderId('future.other'),
          query: query,
        ),
      );
      final result = await PersonalDataAggregationEngine(
        PersonalDataProviderRegistry([provider]),
      ).aggregate(query);

      expect(result.contributions, isEmpty);
      expect(result.failures.single.reasonCode, 'provider_id_mismatch');
    });

    test('duplicate item IDs are rejected without affecting peers', () async {
      final invalid = _provider(
        'future.duplicate',
        collect: (query) async {
          final providerId = PersonalDataProviderId('future.duplicate');
          final item = _item(providerId, 'future.duplicate.item');
          return _contribution(
            providerId: providerId,
            query: query,
            items: [item, item],
          );
        },
      );
      final healthy = _provider('future.healthy');
      final result = await PersonalDataAggregationEngine(
        PersonalDataProviderRegistry([invalid, healthy]),
      ).aggregate(query);

      expect(result.contributions.single.providerId.value, 'future.healthy');
      expect(result.failures.single.reasonCode, 'duplicate_item_id');
    });

    test(
      'provider and capability filters avoid unrelated collection',
      () async {
        final growth = _provider(
          'future.growth',
          capabilities: {PersonalDataCapability('future.growth_progress')},
        );
        final reading = _provider('future.reading');
        final filtered = PersonalDataQuery(
          timeRange: query.timeRange,
          localTimeContext: query.localTimeContext,
          requestedAtUtc: query.requestedAtUtc,
          providerFilter: {PersonalDataProviderId('future.growth')},
        );
        final result = await PersonalDataAggregationEngine(
          PersonalDataProviderRegistry([reading, growth]),
        ).aggregate(filtered);

        expect(result.contributions.single.providerId.value, 'future.growth');
        expect(growth.calls, 1);
        expect(reading.calls, 0);
      },
    );

    test(
      'FakeGrowth provider participates without changing engine or result',
      () async {
        final growth = _provider(
          'future.growth',
          capabilities: {PersonalDataCapability('future.growth_progress')},
        );
        final engine = PersonalDataAggregationEngine(
          PersonalDataProviderRegistry([growth]),
        );

        final result = await engine.aggregate(query);

        expect(
          result.contributions.single.providerId,
          growth.descriptor.providerId,
        );
        expect(
          result.contributions.single.summaryFacts.single.value,
          isA<PersonalDataCountValue>(),
        );
      },
    );
  });
}

_FakeProvider _provider(
  String id, {
  int displayOrder = 100,
  Set<PersonalDataCapability>? capabilities,
  Future<PersonalDataContribution> Function(PersonalDataQuery)? collect,
}) {
  return _FakeProvider(
    descriptor: PersonalDataProviderDescriptor(
      providerId: PersonalDataProviderId(id),
      displayName: id,
      description: 'Test provider',
      providerSchemaVersion: 1,
      capabilities: capabilities ?? {PersonalDataCapability.timeline},
      defaultSensitivity: PersonalDataSensitivity.standardPrivate,
      displayOrder: displayOrder,
    ),
    collector: collect,
  );
}

final class _FakeProvider implements PersonalDataProvider {
  _FakeProvider({required this.descriptor, this.collector});

  @override
  final PersonalDataProviderDescriptor descriptor;
  final Future<PersonalDataContribution> Function(PersonalDataQuery)? collector;
  int calls = 0;

  @override
  Future<PersonalDataContribution> collect(PersonalDataQuery query) async {
    calls++;
    return collector?.call(query) ??
        _contribution(
          providerId: descriptor.providerId,
          query: query,
          capabilities: descriptor.capabilities,
        );
  }
}

PersonalDataContribution _contribution({
  required PersonalDataProviderId providerId,
  required PersonalDataQuery query,
  Set<PersonalDataCapability>? capabilities,
  List<PersonalDataItem> items = const [],
}) {
  return PersonalDataContribution(
    providerId: providerId,
    providerSchemaVersion: 1,
    coveredTimeRange: query.timeRange,
    capabilities: capabilities ?? {PersonalDataCapability.timeline},
    sensitivity: PersonalDataSensitivity.standardPrivate,
    quality: const PersonalDataQuality.complete(),
    items: items,
    summaryFacts: [
      PersonalDataFact(
        key: PersonalDataFactKey('${providerId.value}.count'),
        label: '数量',
        value: PersonalDataCountValue(items.length),
        sensitivity: PersonalDataSensitivity.standardPrivate,
      ),
    ],
    generatedAtUtc: query.requestedAtUtc,
  );
}

PersonalDataItem _item(PersonalDataProviderId providerId, String itemId) {
  return PersonalDataItem(
    id: PersonalDataItemId(itemId),
    kind: PersonalDataItemKind('${providerId.value}.item_kind'),
    title: 'Item',
    sensitivity: PersonalDataSensitivity.standardPrivate,
    quality: const PersonalDataQuality.complete(),
  );
}
