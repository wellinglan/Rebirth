import 'dart:collection';

import 'personal_data_capability.dart';
import 'personal_data_identifier.dart';
import 'personal_data_time_range.dart';

enum PersonalDataAggregationPurpose {
  localOverview,
  localTimeline,
  diagnostics,
}

final class PersonalDataQuery {
  PersonalDataQuery({
    required this.timeRange,
    required this.localTimeContext,
    required DateTime requestedAtUtc,
    this.purpose = PersonalDataAggregationPurpose.localOverview,
    Set<PersonalDataCapability> requestedCapabilities = const {},
    Set<PersonalDataProviderId> providerFilter = const {},
    this.maxItemsPerProvider = 50,
  }) : requestedAtUtc = _requireUtc(requestedAtUtc),
       requestedCapabilities = UnmodifiableSetView(
         Set<PersonalDataCapability>.of(requestedCapabilities),
       ),
       providerFilter = UnmodifiableSetView(
         Set<PersonalDataProviderId>.of(providerFilter),
       ) {
    if (maxItemsPerProvider <= 0 || maxItemsPerProvider > 100) {
      throw ArgumentError.value(
        maxItemsPerProvider,
        'maxItemsPerProvider',
        'Must be between 1 and 100.',
      );
    }
  }

  factory PersonalDataQuery.daily({
    required String localDate,
    required DateTime requestedAtUtc,
    Set<PersonalDataCapability> requestedCapabilities = const {},
    Set<PersonalDataProviderId> providerFilter = const {},
    int maxItemsPerProvider = 50,
  }) {
    final range = PersonalDataTimeRange.forSystemLocalDate(localDate);
    final localStart = range.startInclusiveUtc.toLocal();
    return PersonalDataQuery(
      timeRange: range,
      localTimeContext: PersonalDataLocalTimeContext(
        timezoneOffsetMinutes: localStart.timeZoneOffset.inMinutes,
        timezoneId: 'device-local',
      ),
      requestedAtUtc: requestedAtUtc,
      requestedCapabilities: requestedCapabilities,
      providerFilter: providerFilter,
      maxItemsPerProvider: maxItemsPerProvider,
    );
  }

  final PersonalDataTimeRange timeRange;
  final PersonalDataLocalTimeContext localTimeContext;
  final DateTime requestedAtUtc;
  final PersonalDataAggregationPurpose purpose;
  final Set<PersonalDataCapability> requestedCapabilities;
  final Set<PersonalDataProviderId> providerFilter;
  final int maxItemsPerProvider;
}

DateTime _requireUtc(DateTime value) {
  if (!value.isUtc) {
    throw ArgumentError.value(value, 'requestedAtUtc', 'Must be UTC.');
  }
  return value;
}
