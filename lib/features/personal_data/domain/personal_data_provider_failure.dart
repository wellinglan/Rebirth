import 'personal_data_identifier.dart';

final class PersonalDataProviderFailure {
  const PersonalDataProviderFailure({
    required this.providerId,
    required this.reasonCode,
    required this.message,
  });

  final PersonalDataProviderId providerId;
  final String reasonCode;
  final String message;
}
