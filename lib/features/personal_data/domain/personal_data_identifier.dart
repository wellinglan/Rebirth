final class PersonalDataProviderId
    implements Comparable<PersonalDataProviderId> {
  PersonalDataProviderId(String value)
    : value = _validateNamespaced(value, 'providerId');

  final String value;

  @override
  int compareTo(PersonalDataProviderId other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is PersonalDataProviderId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class PersonalDataItemId implements Comparable<PersonalDataItemId> {
  PersonalDataItemId(String value)
    : value = _validateNamespaced(value, 'itemId');

  final String value;

  @override
  int compareTo(PersonalDataItemId other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is PersonalDataItemId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class PersonalDataItemKind implements Comparable<PersonalDataItemKind> {
  PersonalDataItemKind(String value)
    : value = _validateNamespaced(value, 'itemKind');

  final String value;

  @override
  int compareTo(PersonalDataItemKind other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is PersonalDataItemKind && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class PersonalDataFactKey implements Comparable<PersonalDataFactKey> {
  PersonalDataFactKey(String value)
    : value = _validateNamespaced(value, 'factKey');

  final String value;

  @override
  int compareTo(PersonalDataFactKey other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is PersonalDataFactKey && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final RegExp _namespacedIdentifierPattern = RegExp(
  r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$',
);

String _validateNamespaced(String value, String name) {
  final normalized = value.trim();
  if (normalized != value ||
      !_namespacedIdentifierPattern.hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      name,
      'Must be a stable lowercase namespaced identifier.',
    );
  }
  return normalized;
}
