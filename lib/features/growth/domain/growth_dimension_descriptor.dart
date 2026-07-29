import 'package:rebirth/features/personal_data/domain/personal_data_capability.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_privacy.dart';

import 'growth_identifier.dart';

final class GrowthDimensionDescriptor
    implements Comparable<GrowthDimensionDescriptor> {
  GrowthDimensionDescriptor({
    required this.dimensionId,
    required String displayName,
    required String description,
    required Set<PersonalDataCapability> requiredCapabilities,
    required this.sensitivity,
    this.displayOrder = 100,
  }) : displayName = _requireText(displayName, 'displayName'),
       description = _requireText(description, 'description'),
       requiredCapabilities = Set.unmodifiable(requiredCapabilities);

  final GrowthDimensionId dimensionId;
  final String displayName;
  final String description;
  final Set<PersonalDataCapability> requiredCapabilities;
  final PersonalDataSensitivity sensitivity;
  final int displayOrder;

  @override
  int compareTo(GrowthDimensionDescriptor other) {
    final order = displayOrder.compareTo(other.displayOrder);
    return order != 0 ? order : dimensionId.compareTo(other.dimensionId);
  }
}

String _requireText(String value, String name) {
  final result = value.trim();
  if (result.isEmpty || result.length > 160) {
    throw ArgumentError.value(value, name, 'Must be 1-160 characters.');
  }
  return result;
}
