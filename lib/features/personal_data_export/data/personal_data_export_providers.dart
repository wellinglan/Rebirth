import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/config/app_config_provider.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/files/file_export_provider.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/account/presentation/app_auth_controller.dart';

import '../domain/full_personal_data_export.dart';
import '../domain/personal_data_backup_repository.dart';
import '../domain/personal_data_export_module.dart';
import 'full_personal_data_export_service_impl.dart';
import 'personal_data_backup_repository_impl.dart';
import 'personal_data_export_modules.dart';

final personalDataBackupRepositoryProvider =
    Provider<PersonalDataBackupRepository>((ref) {
      return PersonalDataBackupRepositoryImpl(ref.watch(appDatabaseProvider));
    });

final personalDataExportModuleRegistryProvider =
    Provider<PersonalDataExportModuleRegistry>((ref) {
      final repository = ref.watch(personalDataBackupRepositoryProvider);
      return PersonalDataExportModuleRegistry([
        ProfilePersonalDataExportModule(repository),
        PlanPersonalDataExportModule(repository),
        TodayPersonalDataExportModule(repository),
        JournalPersonalDataExportModule(repository),
        JournalPromptsPersonalDataExportModule(repository),
        HealthPersonalDataExportModule(repository),
        AiReportsPersonalDataExportModule(repository),
        AiReportFeedbackPersonalDataExportModule(repository),
      ]);
    });

final fullPersonalDataExportServiceProvider =
    Provider<FullPersonalDataExportService>((ref) {
      final database = ref.watch(appDatabaseProvider);
      return FullPersonalDataExportServiceImpl(
        registry: ref.watch(personalDataExportModuleRegistryProvider),
        fileExportAdapter: ref.watch(fileExportAdapterProvider),
        dateTimeService: ref.watch(dateTimeServiceProvider),
        activeUserId: () {
          final auth = ref.read(appAuthStateProvider).value;
          if (auth == null || !auth.canAccessBusiness) return null;
          return auth.localUserId;
        },
        readTransaction: database.transaction,
        appVersion: ref.watch(appConfigProvider).appVersionLabel,
        databaseSchemaVersion: database.schemaVersion,
      );
    });
