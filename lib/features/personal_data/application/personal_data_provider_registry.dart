import 'dart:collection';

import '../domain/personal_data_capability.dart';
import '../domain/personal_data_identifier.dart';
import '../domain/personal_data_provider.dart';
import '../domain/personal_data_query.dart';

final class DuplicatePersonalDataProviderException implements Exception {
  const DuplicatePersonalDataProviderException(this.providerId);

  final PersonalDataProviderId providerId;
}

final class PersonalDataProviderRegistry {
  PersonalDataProviderRegistry(Iterable<PersonalDataProvider> providers)
    : _providers = _validatedProviders(providers);

  final List<PersonalDataProvider> _providers;

  List<PersonalDataProvider> get providers => UnmodifiableListView(_providers);

  PersonalDataProvider? providerById(PersonalDataProviderId id) {
    for (final provider in _providers) {
      if (provider.descriptor.providerId == id) return provider;
    }
    return null;
  }

  List<PersonalDataProvider> providersForCapability(
    PersonalDataCapability capability,
  ) {
    return UnmodifiableListView(
      _providers
          .where(
            (provider) => provider.descriptor.capabilities.contains(capability),
          )
          .toList(growable: false),
    );
  }

  List<PersonalDataProvider> select(PersonalDataQuery query) {
    final selected = _providers
        .where((provider) {
          final descriptor = provider.descriptor;
          if (query.providerFilter.isNotEmpty &&
              !query.providerFilter.contains(descriptor.providerId)) {
            return false;
          }
          if (query.requestedCapabilities.isEmpty) return true;
          return descriptor.capabilities.any(
            query.requestedCapabilities.contains,
          );
        })
        .toList(growable: false);
    return UnmodifiableListView(selected);
  }
}

List<PersonalDataProvider> _validatedProviders(
  Iterable<PersonalDataProvider> providers,
) {
  final result = List<PersonalDataProvider>.of(providers);
  final ids = <PersonalDataProviderId>{};
  for (final provider in result) {
    final id = provider.descriptor.providerId;
    if (!ids.add(id)) {
      throw DuplicatePersonalDataProviderException(id);
    }
  }
  result.sort((first, second) {
    final order = first.descriptor.displayOrder.compareTo(
      second.descriptor.displayOrder,
    );
    return order != 0
        ? order
        : first.descriptor.providerId.compareTo(second.descriptor.providerId);
  });
  return List<PersonalDataProvider>.unmodifiable(result);
}
