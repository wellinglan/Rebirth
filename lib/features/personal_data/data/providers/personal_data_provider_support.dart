import 'package:crypto/crypto.dart';

import '../../domain/personal_data_fact.dart';
import '../../domain/personal_data_identifier.dart';
import '../../domain/personal_data_privacy.dart';
import '../../domain/personal_data_quality.dart';
import '../../domain/personal_data_value.dart';

PersonalDataItemId protectedItemId(
  PersonalDataProviderId providerId,
  String sourceId,
) {
  final digest = sha256.convert(sourceId.codeUnits).toString().substring(0, 16);
  return PersonalDataItemId('${providerId.value}.i$digest');
}

PersonalDataQuality qualityForSyncStatus(String syncStatus) {
  return syncStatus == 'conflict'
      ? const PersonalDataQuality.conflicted()
      : const PersonalDataQuality.complete();
}

PersonalDataQuality contributionQuality({
  required bool hasConflict,
  required bool wasLimited,
}) {
  if (hasConflict) return const PersonalDataQuality.conflicted();
  if (wasLimited) {
    return const PersonalDataQuality.partial('result_limit_applied');
  }
  return const PersonalDataQuality.complete();
}

PersonalDataFact fact({
  required String key,
  required String label,
  required PersonalDataValue value,
  required PersonalDataSensitivity sensitivity,
  String? unit,
  int priority = 100,
}) {
  return PersonalDataFact(
    key: PersonalDataFactKey(key),
    label: label,
    value: value,
    sensitivity: sensitivity,
    unit: unit,
    displayPriority: priority,
  );
}

DateTime utcDateTimeFromMilliseconds(int milliseconds) {
  return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
}

String boundedTitle(String value, {required String fallback}) {
  final normalized = value.trim();
  if (normalized.isEmpty) return fallback;
  return normalized.length <= 120 ? normalized : normalized.substring(0, 120);
}
