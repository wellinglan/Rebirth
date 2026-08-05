import 'personal_data_backup.dart';

abstract interface class PersonalDataBackupRepository {
  Future<ProfileBackupRecord> readProfile(String localUserId);

  Future<List<PlanGoalBackupRecord>> readPlan(String localUserId);

  Future<List<TodayBackupRecord>> readToday(String localUserId);

  Future<List<JournalBackupRecord>> readJournal(String localUserId);

  Future<List<JournalPromptConfigurationBackupRecord>> readJournalPrompts(
    String localUserId,
  );

  Future<List<HealthBackupRecord>> readHealth(String localUserId);

  Future<List<AiReportBackupRecord>> readAiReports(String localUserId);
}

final class PersonalDataBackupSourceException implements Exception {
  const PersonalDataBackupSourceException();
}
