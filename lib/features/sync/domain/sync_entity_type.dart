enum SyncEntityType {
  profile('user_profiles'),
  today('today_records'),
  journalPromptConfiguration('journal_prompt_configurations'),
  journal('journal_entries'),
  plan('goals'),
  health('health_records'),
  aiReport('ai_reports');

  const SyncEntityType(this.wireName);

  final String wireName;

  static SyncEntityType parse(String value) {
    for (final type in values) {
      if (type.wireName == value) return type;
    }
    throw SyncUnsupportedEntityException(value);
  }
}

final class SyncUnsupportedEntityException implements Exception {
  const SyncUnsupportedEntityException(this.entityType);

  final String entityType;

  @override
  String toString() => 'No sync adapter is registered for $entityType.';
}
