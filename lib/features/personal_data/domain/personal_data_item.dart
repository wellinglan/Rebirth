import 'dart:collection';

import 'personal_data_fact.dart';
import 'personal_data_identifier.dart';
import 'personal_data_privacy.dart';
import 'personal_data_quality.dart';

final class PersonalDataReference {
  PersonalDataReference({
    required this.providerId,
    required this.itemId,
    required String relation,
  }) : relation = relation.trim() {
    if (this.relation.isEmpty || this.relation.length > 40) {
      throw ArgumentError.value(relation, 'relation', 'Must be 1-40 chars.');
    }
  }

  final PersonalDataProviderId providerId;
  final PersonalDataItemId itemId;
  final String relation;
}

final class PersonalDataItem implements Comparable<PersonalDataItem> {
  PersonalDataItem({
    required this.id,
    required this.kind,
    required String title,
    required this.sensitivity,
    required this.quality,
    List<PersonalDataFact> facts = const [],
    List<PersonalDataReference> references = const [],
    this.localDate,
    this.occurredAtUtc,
    this.intervalStartUtc,
    this.intervalEndExclusiveUtc,
    this.displayOrder = 100,
  }) : title = _validateTitle(title),
       facts = UnmodifiableListView(_sortedFacts(facts)),
       references = UnmodifiableListView(
         List<PersonalDataReference>.of(references),
       ) {
    if (localDate != null) {
      _dateAsUtc(localDate);
    }
    if (occurredAtUtc != null && !occurredAtUtc!.isUtc) {
      throw ArgumentError.value(occurredAtUtc, 'occurredAtUtc', 'Must be UTC.');
    }
    if ((intervalStartUtc == null) != (intervalEndExclusiveUtc == null)) {
      throw ArgumentError('Interval start and end must be supplied together.');
    }
    if (intervalStartUtc != null) {
      if (!intervalStartUtc!.isUtc ||
          !intervalEndExclusiveUtc!.isUtc ||
          !intervalStartUtc!.isBefore(intervalEndExclusiveUtc!)) {
        throw ArgumentError('Interval must be a valid increasing UTC range.');
      }
    }
  }

  final PersonalDataItemId id;
  final PersonalDataItemKind kind;
  final String title;
  final String? localDate;
  final DateTime? occurredAtUtc;
  final DateTime? intervalStartUtc;
  final DateTime? intervalEndExclusiveUtc;
  final List<PersonalDataFact> facts;
  final List<PersonalDataReference> references;
  final PersonalDataSensitivity sensitivity;
  final PersonalDataQuality quality;
  final int displayOrder;

  @override
  int compareTo(PersonalDataItem other) {
    final thisTime = occurredAtUtc ?? intervalStartUtc ?? _dateAsUtc(localDate);
    final otherTime =
        other.occurredAtUtc ??
        other.intervalStartUtc ??
        _dateAsUtc(other.localDate);
    final time = _compareNullableDateTime(thisTime, otherTime);
    if (time != 0) return time;
    final order = displayOrder.compareTo(other.displayOrder);
    return order != 0 ? order : id.compareTo(other.id);
  }
}

List<PersonalDataFact> _sortedFacts(List<PersonalDataFact> facts) {
  final result = List<PersonalDataFact>.of(facts)..sort();
  return result;
}

String _validateTitle(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 120) {
    throw ArgumentError.value(value, 'title', 'Must be 1-120 characters.');
  }
  return normalized;
}

DateTime? _dateAsUtc(String? value) {
  if (value == null) return null;
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw ArgumentError.value(value, 'localDate', 'Must use YYYY-MM-DD.');
  }
  final parts = value.split('-').map(int.parse).toList(growable: false);
  final result = DateTime.utc(parts[0], parts[1], parts[2]);
  if (result.year != parts[0] ||
      result.month != parts[1] ||
      result.day != parts[2]) {
    throw ArgumentError.value(value, 'localDate', 'Must be a valid date.');
  }
  return result;
}

int _compareNullableDateTime(DateTime? first, DateTime? second) {
  if (first == null && second == null) return 0;
  if (first == null) return 1;
  if (second == null) return -1;
  return first.compareTo(second);
}
