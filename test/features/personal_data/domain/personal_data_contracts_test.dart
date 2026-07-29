import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_capability.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_identifier.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_query.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_time_range.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_value.dart';

void main() {
  group('namespaced identifiers and capabilities', () {
    test('valid built-in and future identifiers are supported', () {
      expect(PersonalDataProviderId('future.growth').value, 'future.growth');
      expect(
        PersonalDataCapability('future.growth_progress').value,
        'future.growth_progress',
      );
      expect(PersonalDataCapability.identity.value, 'core.identity');
    });

    test('empty, spaced, uppercase, and unnamespaced identifiers fail', () {
      for (final value in ['', 'profile', 'core bad.value', 'Core.value']) {
        expect(
          () => PersonalDataProviderId(value),
          throwsArgumentError,
          reason: value,
        );
      }
    });

    test('identifier equality makes filters deterministic', () {
      expect({
        PersonalDataProviderId('rebirth.today'),
      }, contains(PersonalDataProviderId('rebirth.today')));
    });
  });

  group('time range and query', () {
    test('daily range uses start-inclusive and end-exclusive UTC bounds', () {
      final range = PersonalDataTimeRange.forLocalDate(
        localDate: '2026-07-29',
        timeContext: const PersonalDataLocalTimeContext(
          timezoneOffsetMinutes: 480,
        ),
      );

      expect(range.startInclusiveUtc, DateTime.utc(2026, 7, 28, 16));
      expect(range.endExclusiveUtc, DateTime.utc(2026, 7, 29, 16));
      expect(range.containsUtc(DateTime.utc(2026, 7, 29)), isTrue);
      expect(range.containsUtc(range.endExclusiveUtc), isFalse);
    });

    test('negative timezone offset is represented explicitly', () {
      final range = PersonalDataTimeRange.forLocalDate(
        localDate: '2026-07-29',
        timeContext: const PersonalDataLocalTimeContext(
          timezoneOffsetMinutes: -300,
        ),
      );

      expect(range.startInclusiveUtc, DateTime.utc(2026, 7, 29, 5));
      expect(range.endExclusiveUtc, DateTime.utc(2026, 7, 30, 5));
    });

    test('custom multi-day range and deterministic clock are supported', () {
      final query = PersonalDataQuery(
        timeRange: PersonalDataTimeRange(
          startInclusiveUtc: DateTime.utc(2026, 7, 1),
          endExclusiveUtc: DateTime.utc(2026, 7, 8),
          startLocalDate: '2026-07-01',
          endLocalDateInclusive: '2026-07-07',
        ),
        localTimeContext: const PersonalDataLocalTimeContext(
          timezoneOffsetMinutes: 0,
        ),
        requestedAtUtc: DateTime.utc(2026, 7, 8, 1),
        requestedCapabilities: {
          PersonalDataCapability('future.growth_progress'),
        },
        maxItemsPerProvider: 25,
      );

      expect(query.timeRange.endLocalDateInclusive, '2026-07-07');
      expect(query.requestedAtUtc, DateTime.utc(2026, 7, 8, 1));
      expect(query.maxItemsPerProvider, 25);
    });

    test('invalid ranges, dates, clocks, and result limits fail', () {
      expect(
        () => PersonalDataTimeRange.forSystemLocalDate('2026-02-30'),
        throwsArgumentError,
      );
      expect(
        () => PersonalDataTimeRange(
          startInclusiveUtc: DateTime.utc(2026, 7, 2),
          endExclusiveUtc: DateTime.utc(2026, 7, 1),
          startLocalDate: '2026-07-01',
          endLocalDateInclusive: '2026-07-02',
        ),
        throwsArgumentError,
      );
      expect(
        () => PersonalDataQuery.daily(
          localDate: '2026-07-29',
          requestedAtUtc: DateTime(2026, 7, 29),
        ),
        throwsArgumentError,
      );
      expect(
        () => PersonalDataQuery.daily(
          localDate: '2026-07-29',
          requestedAtUtc: DateTime.utc(2026, 7, 29),
          maxItemsPerProvider: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('strongly typed values', () {
    test('all supported value types preserve their concrete type', () {
      final values = <PersonalDataValue>[
        PersonalDataTextValue('summary', isSummary: true),
        const PersonalDataIntegerValue(0),
        PersonalDataDecimalValue(1.5),
        const PersonalDataBooleanValue(false),
        PersonalDataDurationValue(minutes: 0),
        PersonalDataCountValue(0),
        PersonalDataScoreValue(value: 3, minimum: 1, maximum: 5),
        PersonalDataDateValue('2026-07-29'),
        PersonalDataDateTimeValue(DateTime.utc(2026, 7, 29)),
        PersonalDataPercentageValue(0),
        PersonalDataCategoricalValue('in_progress'),
        const PersonalDataPresenceValue(false),
      ];

      expect(values, hasLength(12));
      expect(values[1], isA<PersonalDataIntegerValue>());
      expect((values[1] as PersonalDataIntegerValue).value, 0);
      expect((values[3] as PersonalDataBooleanValue).value, isFalse);
      expect((values[4] as PersonalDataDurationValue).minutes, 0);
    });

    test('invalid text, duration, score, percentage, and date fail', () {
      expect(() => PersonalDataTextValue(''), throwsArgumentError);
      expect(
        () => PersonalDataTextValue(List.filled(121, 'x').join()),
        throwsArgumentError,
      );
      expect(() => PersonalDataDurationValue(minutes: -1), throwsArgumentError);
      expect(
        () => PersonalDataScoreValue(value: 6, minimum: 1, maximum: 5),
        throwsArgumentError,
      );
      expect(() => PersonalDataPercentageValue(101), throwsArgumentError);
      expect(() => PersonalDataDateValue('2026-02-30'), throwsArgumentError);
    });
  });
}
