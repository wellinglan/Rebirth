import 'dart:collection';

import 'personal_data_capability.dart';
import 'personal_data_identifier.dart';
import 'personal_data_privacy.dart';

final class PersonalDataProviderDescriptor {
  PersonalDataProviderDescriptor({
    required this.providerId,
    required String displayName,
    required String description,
    required this.providerSchemaVersion,
    required Set<PersonalDataCapability> capabilities,
    required this.defaultSensitivity,
    required this.displayOrder,
  }) : displayName = _validatedText(displayName, 'displayName', 40),
       description = _validatedText(description, 'description', 120),
       capabilities = UnmodifiableSetView(
         Set<PersonalDataCapability>.of(capabilities),
       ) {
    if (providerSchemaVersion <= 0) {
      throw ArgumentError.value(
        providerSchemaVersion,
        'providerSchemaVersion',
        'Must be positive.',
      );
    }
    if (this.capabilities.isEmpty) {
      throw ArgumentError('Provider must declare at least one capability.');
    }
  }

  final PersonalDataProviderId providerId;
  final String displayName;
  final String description;
  final int providerSchemaVersion;
  final Set<PersonalDataCapability> capabilities;
  final PersonalDataSensitivity defaultSensitivity;
  final int displayOrder;
}

String _validatedText(String value, String name, int maxLength) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > maxLength) {
    throw ArgumentError.value(
      value,
      name,
      'Must be non-empty and no longer than $maxLength characters.',
    );
  }
  return normalized;
}
