import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart';

import '../../domain/personal_data_capability.dart';
import '../../domain/personal_data_contribution.dart';
import '../../domain/personal_data_identifier.dart';
import '../../domain/personal_data_item.dart';
import '../../domain/personal_data_privacy.dart';
import '../../domain/personal_data_provider.dart';
import '../../domain/personal_data_provider_descriptor.dart';
import '../../domain/personal_data_query.dart';
import '../../domain/personal_data_quality.dart';
import '../../domain/personal_data_value.dart';
import 'personal_data_provider_support.dart';

final class ProfilePersonalDataProvider implements PersonalDataProvider {
  const ProfilePersonalDataProvider({
    required this.database,
    required this.localUserId,
  });

  static final providerId = PersonalDataProviderId('rebirth.profile');

  static final _descriptor = PersonalDataProviderDescriptor(
    providerId: providerId,
    displayName: '个人资料',
    description: '当前账号的本地个人上下文摘要',
    providerSchemaVersion: 1,
    capabilities: {PersonalDataCapability.identity},
    defaultSensitivity: PersonalDataSensitivity.sensitive,
    displayOrder: 10,
  );

  final AppDatabase database;
  final String localUserId;

  @override
  PersonalDataProviderDescriptor get descriptor => _descriptor;

  @override
  Future<PersonalDataContribution> collect(PersonalDataQuery query) async {
    final profile =
        await (database.select(database.userProfiles)..where(
              (row) =>
                  row.id.equals(localUserId) &
                  row.isActive.equals(true) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    final sensitivity = descriptor.defaultSensitivity;
    final items = profile == null
        ? const <PersonalDataItem>[]
        : [
            PersonalDataItem(
              id: protectedItemId(providerId, profile.id),
              kind: PersonalDataItemKind('profile.local_context'),
              title: '当前本地资料',
              occurredAtUtc: utcDateTimeFromMilliseconds(profile.updatedAt),
              facts: [
                fact(
                  key: 'profile.display_name_set',
                  label: '已设置昵称',
                  value: PersonalDataPresenceValue(
                    profile.displayName?.trim().isNotEmpty ?? false,
                  ),
                  sensitivity: sensitivity,
                  priority: 10,
                ),
                fact(
                  key: 'profile.growth_focus_set',
                  label: '已设置成长方向',
                  value: PersonalDataPresenceValue(
                    profile.growthFocus?.trim().isNotEmpty ?? false,
                  ),
                  sensitivity: sensitivity,
                  priority: 20,
                ),
                fact(
                  key: 'profile.timezone',
                  label: '时区',
                  value: PersonalDataCategoricalValue(profile.timezoneId),
                  sensitivity: sensitivity,
                  priority: 30,
                ),
              ],
              sensitivity: sensitivity,
              quality: qualityForSyncStatus(profile.syncStatus),
            ),
          ];
    return PersonalDataContribution(
      providerId: providerId,
      providerSchemaVersion: descriptor.providerSchemaVersion,
      coveredTimeRange: query.timeRange,
      capabilities: descriptor.capabilities,
      sensitivity: sensitivity,
      quality: profile?.syncStatus == 'conflict'
          ? const PersonalDataQuality.conflicted()
          : const PersonalDataQuality.complete(),
      items: items,
      summaryFacts: [
        fact(
          key: 'profile.record_present',
          label: '资料存在',
          value: PersonalDataPresenceValue(profile != null),
          sensitivity: sensitivity,
          priority: 0,
        ),
      ],
      generatedAtUtc: query.requestedAtUtc,
    );
  }
}
