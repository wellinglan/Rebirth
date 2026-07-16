import 'ai_data_authorization.dart';

abstract interface class AiConsentRepository {
  Future<AiDataAuthorization> read();

  Future<AiDataAuthorization> grant();

  Future<AiDataAuthorization> revoke();
}
