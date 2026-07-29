import 'package:rebirth/features/personal_data/domain/personal_data_identifier.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_privacy.dart';
import 'package:rebirth/features/personal_data/domain/personal_data_quality.dart';

final class GrowthEvidence implements Comparable<GrowthEvidence> {
  const GrowthEvidence({
    required this.providerId,
    required this.itemId,
    required this.factKey,
    required this.localDate,
    required this.quality,
    required this.sensitivity,
  });

  final PersonalDataProviderId providerId;
  final PersonalDataItemId itemId;
  final PersonalDataFactKey factKey;
  final String? localDate;
  final PersonalDataQuality quality;
  final PersonalDataSensitivity sensitivity;

  @override
  int compareTo(GrowthEvidence other) {
    final provider = providerId.compareTo(other.providerId);
    if (provider != 0) return provider;
    final date = (localDate ?? '').compareTo(other.localDate ?? '');
    if (date != 0) return date;
    final item = itemId.compareTo(other.itemId);
    return item != 0 ? item : factKey.compareTo(other.factKey);
  }
}
