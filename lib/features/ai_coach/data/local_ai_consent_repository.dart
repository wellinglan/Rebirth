import 'package:drift/drift.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/ai_coach/domain/ai_consent_repository.dart';
import 'package:rebirth/features/ai_coach/domain/ai_data_authorization.dart';

final class LocalAiConsentRepository implements AiConsentRepository {
  const LocalAiConsentRepository({
    required this.database,
    required this.dateTimeService,
  });

  final AppDatabase database;
  final DateTimeService dateTimeService;

  @override
  Future<AiDataAuthorization> read() async {
    final bootstrap = await database.bootstrapDao.bootstrap();
    return _toDomain(bootstrap.settings);
  }

  @override
  Future<AiDataAuthorization> grant() async {
    final bootstrap = await database.bootstrapDao.bootstrap();
    final current = _toDomain(bootstrap.settings);
    if (current.enabled) return current;

    final now = dateTimeService.currentSnapshot().utcMilliseconds;
    await (database.update(database.appSettings)
          ..where((row) => row.id.equals(bootstrap.settings.id)))
        .write(
          AppSettingsCompanion(
            aiDataSharingEnabled: const Value(true),
            aiDataSharingConsentAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return AiDataAuthorization(enabled: true, consentAt: now);
  }

  @override
  Future<AiDataAuthorization> revoke() async {
    final bootstrap = await database.bootstrapDao.bootstrap();
    final current = _toDomain(bootstrap.settings);
    if (!current.enabled) return current;

    final now = dateTimeService.currentSnapshot().utcMilliseconds;
    await (database.update(database.appSettings)
          ..where((row) => row.id.equals(bootstrap.settings.id)))
        .write(
          AppSettingsCompanion(
            aiDataSharingEnabled: const Value(false),
            updatedAt: Value(now),
          ),
        );
    return AiDataAuthorization(enabled: false, consentAt: current.consentAt);
  }

  AiDataAuthorization _toDomain(AppSetting settings) {
    return AiDataAuthorization(
      enabled: settings.aiDataSharingEnabled,
      consentAt: settings.aiDataSharingConsentAt,
    );
  }
}
