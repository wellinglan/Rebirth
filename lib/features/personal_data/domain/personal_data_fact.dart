import 'personal_data_identifier.dart';
import 'personal_data_privacy.dart';
import 'personal_data_value.dart';

final class PersonalDataFact implements Comparable<PersonalDataFact> {
  PersonalDataFact({
    required this.key,
    required String label,
    required this.value,
    required this.sensitivity,
    this.unit,
    this.displayPriority = 100,
  }) : label = _requireLabel(label);

  final PersonalDataFactKey key;
  final String label;
  final PersonalDataValue value;
  final PersonalDataSensitivity sensitivity;
  final String? unit;
  final int displayPriority;

  @override
  int compareTo(PersonalDataFact other) {
    final priority = displayPriority.compareTo(other.displayPriority);
    return priority != 0 ? priority : key.compareTo(other.key);
  }
}

String _requireLabel(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 40) {
    throw ArgumentError.value(
      value,
      'label',
      'Must be non-empty and no longer than 40 characters.',
    );
  }
  return normalized;
}
