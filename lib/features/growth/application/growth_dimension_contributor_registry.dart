import 'dart:collection';

import 'package:rebirth/features/growth/domain/growth_dimension_contributor.dart';
import 'package:rebirth/features/growth/domain/growth_identifier.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_capability.dart';

final class GrowthDimensionContributorRegistry {
  GrowthDimensionContributorRegistry(
    Iterable<GrowthDimensionContributor> contributors,
  ) : _contributors = _validateAndSort(contributors);

  final List<GrowthDimensionContributor> _contributors;

  List<GrowthDimensionContributor> get contributors =>
      UnmodifiableListView(_contributors);

  GrowthDimensionContributor? byId(GrowthDimensionId id) {
    for (final contributor in _contributors) {
      if (contributor.descriptor.dimensionId == id) return contributor;
    }
    return null;
  }

  List<GrowthDimensionContributor> requiring(
    PersonalDataCapability capability,
  ) {
    return UnmodifiableListView(
      _contributors
          .where(
            (contributor) =>
                contributor.requiredCapabilities.contains(capability),
          )
          .toList(growable: false),
    );
  }
}

List<GrowthDimensionContributor> _validateAndSort(
  Iterable<GrowthDimensionContributor> contributors,
) {
  final result = List<GrowthDimensionContributor>.of(contributors);
  final ids = <GrowthDimensionId>{};
  for (final contributor in result) {
    if (!ids.add(contributor.descriptor.dimensionId)) {
      throw ArgumentError(
        'Duplicate Growth dimension ID: ${contributor.descriptor.dimensionId}',
      );
    }
    if (!contributor.descriptor.requiredCapabilities.containsAll(
      contributor.requiredCapabilities,
    )) {
      throw ArgumentError(
        'Contributor capabilities must match its descriptor.',
      );
    }
  }
  result.sort((left, right) => left.descriptor.compareTo(right.descriptor));
  return List.unmodifiable(result);
}
