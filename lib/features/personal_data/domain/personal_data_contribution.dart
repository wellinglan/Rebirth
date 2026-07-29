import 'dart:collection';

import 'personal_data_capability.dart';
import 'personal_data_fact.dart';
import 'personal_data_identifier.dart';
import 'personal_data_item.dart';
import 'personal_data_privacy.dart';
import 'personal_data_quality.dart';
import 'personal_data_time_range.dart';

final class PersonalDataContribution {
  PersonalDataContribution({
    required this.providerId,
    required this.providerSchemaVersion,
    required this.coveredTimeRange,
    required Set<PersonalDataCapability> capabilities,
    required this.sensitivity,
    required this.quality,
    required List<PersonalDataItem> items,
    List<PersonalDataFact> summaryFacts = const [],
    required DateTime generatedAtUtc,
  }) : capabilities = UnmodifiableSetView(
         Set<PersonalDataCapability>.of(capabilities),
       ),
       items = UnmodifiableListView(_sortedItems(items)),
       summaryFacts = UnmodifiableListView(_sortedFacts(summaryFacts)),
       generatedAtUtc = _requireUtc(generatedAtUtc);

  final PersonalDataProviderId providerId;
  final int providerSchemaVersion;
  final PersonalDataTimeRange coveredTimeRange;
  final Set<PersonalDataCapability> capabilities;
  final PersonalDataSensitivity sensitivity;
  final PersonalDataQuality quality;
  final List<PersonalDataItem> items;
  final List<PersonalDataFact> summaryFacts;
  final DateTime generatedAtUtc;

  bool get isEmpty => items.isEmpty && summaryFacts.isEmpty;
}

List<PersonalDataItem> _sortedItems(List<PersonalDataItem> items) {
  final result = List<PersonalDataItem>.of(items)..sort();
  return result;
}

List<PersonalDataFact> _sortedFacts(List<PersonalDataFact> facts) {
  final result = List<PersonalDataFact>.of(facts)..sort();
  return result;
}

DateTime _requireUtc(DateTime value) {
  if (!value.isUtc) {
    throw ArgumentError.value(value, 'generatedAtUtc', 'Must be UTC.');
  }
  return value;
}
