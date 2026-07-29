import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/account/domain/app_auth_state.dart';
import 'package:rebirth/features/account/presentation/app_auth_controller.dart';
import 'package:rebirth/features/personal_data/application/personal_data_aggregation_controller.dart';
import 'package:rebirth/features/personal_data/application/personal_data_provider_registry.dart';
import 'package:rebirth/features/personal_data/application/personal_data_providers.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_capability.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_contribution.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_identifier.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_privacy.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_provider.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_provider_descriptor.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_quality.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_query.dart';

void main() {
  late ProviderContainer container;
  late _QueuedProvider provider;

  setUp(() {
    provider = _QueuedProvider();
    container = ProviderContainer(
      overrides: [
        appAuthStateProvider.overrideWithValue(
          const AsyncData(
            AppAuthState(
              status: AppAuthStatus.authenticatedOffline,
              localUserId: 'local-user-a',
            ),
          ),
        ),
        dateTimeServiceProvider.overrideWithValue(
          DateTimeService(now: () => DateTime(2026, 7, 29, 10)),
        ),
        personalDataProviderRegistryProvider.overrideWithValue(
          PersonalDataProviderRegistry([provider]),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  test(
    'initial load works for authenticatedOffline and uses fixed clock',
    () async {
      final state = await container.read(
        personalDataAggregationControllerProvider.future,
      );

      expect(state.selectedDate, '2026-07-29');
      expect(state.result, isNotNull);
      expect(provider.queries.single.timeRange.startLocalDate, '2026-07-29');
      expect(provider.queries.single.requestedAtUtc.isUtc, isTrue);
    },
  );

  test('date navigation and today action reload the selected date', () async {
    await container.read(personalDataAggregationControllerProvider.future);
    final controller = container.read(
      personalDataAggregationControllerProvider.notifier,
    );

    await controller.previousDay();
    expect(
      container
          .read(personalDataAggregationControllerProvider)
          .value
          ?.selectedDate,
      '2026-07-28',
    );
    await controller.nextDay();
    await controller.goToToday();

    expect(
      container
          .read(personalDataAggregationControllerProvider)
          .value
          ?.selectedDate,
      '2026-07-29',
    );
  });

  test('duplicate refresh is ignored while the same date is loading', () async {
    await container.read(personalDataAggregationControllerProvider.future);
    final gate = Completer<PersonalDataContribution>();
    provider.enqueue(gate.future);
    final controller = container.read(
      personalDataAggregationControllerProvider.notifier,
    );

    final first = controller.refresh();
    final second = controller.refresh();
    expect(provider.queries, hasLength(2));
    gate.complete(_contribution(provider.descriptor, provider.queries.last));
    await Future.wait([first, second]);

    expect(provider.queries, hasLength(2));
  });

  test('a stale date result cannot overwrite a newer date', () async {
    await container.read(personalDataAggregationControllerProvider.future);
    final firstGate = Completer<PersonalDataContribution>();
    final secondGate = Completer<PersonalDataContribution>();
    provider
      ..enqueue(firstGate.future)
      ..enqueue(secondGate.future);
    final controller = container.read(
      personalDataAggregationControllerProvider.notifier,
    );

    final first = controller.nextDay();
    await Future<void>.delayed(Duration.zero);
    final second = controller.nextDay();
    await Future<void>.delayed(Duration.zero);

    secondGate.complete(
      _contribution(provider.descriptor, provider.queries.last),
    );
    await second;
    firstGate.complete(_contribution(provider.descriptor, provider.queries[1]));
    await first;

    final state = container
        .read(personalDataAggregationControllerProvider)
        .value!;
    expect(state.selectedDate, '2026-07-31');
    expect(state.result?.query.timeRange.startLocalDate, '2026-07-31');
  });

  test(
    'provider failure becomes a partial result and remains retryable',
    () async {
      await container.read(personalDataAggregationControllerProvider.future);
      provider.enqueue(Future.error(StateError('private failure')));
      final controller = container.read(
        personalDataAggregationControllerProvider.notifier,
      );

      await controller.refresh();
      final failed = container
          .read(personalDataAggregationControllerProvider)
          .value!;
      expect(failed.result, isNotNull);
      expect(failed.errorMessage, isNull);
      expect(failed.result?.failures, hasLength(1));

      await controller.refresh();
      final recovered = container
          .read(personalDataAggregationControllerProvider)
          .value!;
      expect(recovered.errorMessage, isNull);
      expect(recovered.result, isNotNull);
      expect(recovered.result?.failures, isEmpty);
    },
  );
}

final class _QueuedProvider implements PersonalDataProvider {
  _QueuedProvider();

  @override
  final descriptor = PersonalDataProviderDescriptor(
    providerId: PersonalDataProviderId('future.controller_test'),
    displayName: 'Controller Test',
    description: 'Controller test provider',
    providerSchemaVersion: 1,
    capabilities: {PersonalDataCapability.timeline},
    defaultSensitivity: PersonalDataSensitivity.standardPrivate,
    displayOrder: 10,
  );

  final List<PersonalDataQuery> queries = [];
  final List<Future<PersonalDataContribution>> _queued = [];

  void enqueue(Future<PersonalDataContribution> result) {
    _queued.add(result);
  }

  @override
  Future<PersonalDataContribution> collect(PersonalDataQuery query) {
    queries.add(query);
    if (_queued.isNotEmpty) return _queued.removeAt(0);
    return Future.value(_contribution(descriptor, query));
  }
}

PersonalDataContribution _contribution(
  PersonalDataProviderDescriptor descriptor,
  PersonalDataQuery query,
) {
  return PersonalDataContribution(
    providerId: descriptor.providerId,
    providerSchemaVersion: descriptor.providerSchemaVersion,
    coveredTimeRange: query.timeRange,
    capabilities: descriptor.capabilities,
    sensitivity: descriptor.defaultSensitivity,
    quality: const PersonalDataQuality.complete(),
    items: const [],
    generatedAtUtc: query.requestedAtUtc,
  );
}
