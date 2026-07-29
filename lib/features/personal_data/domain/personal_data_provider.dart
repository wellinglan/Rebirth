import 'personal_data_contribution.dart';
import 'personal_data_provider_descriptor.dart';
import 'personal_data_query.dart';

abstract interface class PersonalDataProvider {
  PersonalDataProviderDescriptor get descriptor;

  Future<PersonalDataContribution> collect(PersonalDataQuery query);
}
