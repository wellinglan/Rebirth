import '../domain/personal_data_backup.dart';
import '../domain/personal_data_backup_repository.dart';
import '../domain/personal_data_export_module.dart';

final class ProfilePersonalDataExportModule
    implements PersonalDataExportModule {
  const ProfilePersonalDataExportModule(this.repository);

  final PersonalDataBackupRepository repository;

  @override
  String get id => 'profile';

  @override
  Future<PersonalDataModuleSnapshot> export(String localUserId) async {
    return PersonalDataModuleSnapshot(
      id: id,
      records: [await repository.readProfile(localUserId)],
    );
  }
}

final class PlanPersonalDataExportModule implements PersonalDataExportModule {
  const PlanPersonalDataExportModule(this.repository);

  final PersonalDataBackupRepository repository;

  @override
  String get id => 'plan';

  @override
  Future<PersonalDataModuleSnapshot> export(String localUserId) async {
    return PersonalDataModuleSnapshot(
      id: id,
      records: await repository.readPlan(localUserId),
    );
  }
}

final class TodayPersonalDataExportModule implements PersonalDataExportModule {
  const TodayPersonalDataExportModule(this.repository);

  final PersonalDataBackupRepository repository;

  @override
  String get id => 'today';

  @override
  Future<PersonalDataModuleSnapshot> export(String localUserId) async {
    return PersonalDataModuleSnapshot(
      id: id,
      records: await repository.readToday(localUserId),
    );
  }
}

final class JournalPersonalDataExportModule
    implements PersonalDataExportModule {
  const JournalPersonalDataExportModule(this.repository);

  final PersonalDataBackupRepository repository;

  @override
  String get id => 'journal';

  @override
  Future<PersonalDataModuleSnapshot> export(String localUserId) async {
    return PersonalDataModuleSnapshot(
      id: id,
      records: await repository.readJournal(localUserId),
    );
  }
}

final class JournalPromptsPersonalDataExportModule
    implements PersonalDataExportModule {
  const JournalPromptsPersonalDataExportModule(this.repository);

  final PersonalDataBackupRepository repository;

  @override
  String get id => 'journal_prompt_configurations';

  @override
  Future<PersonalDataModuleSnapshot> export(String localUserId) async {
    return PersonalDataModuleSnapshot(
      id: id,
      records: await repository.readJournalPrompts(localUserId),
    );
  }
}

final class HealthPersonalDataExportModule implements PersonalDataExportModule {
  const HealthPersonalDataExportModule(this.repository);

  final PersonalDataBackupRepository repository;

  @override
  String get id => 'health';

  @override
  Future<PersonalDataModuleSnapshot> export(String localUserId) async {
    return PersonalDataModuleSnapshot(
      id: id,
      records: await repository.readHealth(localUserId),
    );
  }
}

final class AiReportsPersonalDataExportModule
    implements PersonalDataExportModule {
  const AiReportsPersonalDataExportModule(this.repository);

  final PersonalDataBackupRepository repository;

  @override
  String get id => 'ai_reports';

  @override
  Future<PersonalDataModuleSnapshot> export(String localUserId) async {
    return PersonalDataModuleSnapshot(
      id: id,
      records: await repository.readAiReports(localUserId),
    );
  }
}
