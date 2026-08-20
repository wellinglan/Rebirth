import 'package:drift/drift.dart';
import 'package:rebirth/core/journal/journal_prompt_catalog.dart';
import 'package:rebirth/core/utils/deterministic_uuid.dart';

import 'daos/bootstrap_dao.dart';
import 'database_connection.dart';
import 'tables/ai_reports_table.dart';
import 'tables/ai_report_versions_table.dart';
import 'tables/ai_report_feedback_table.dart';
import 'tables/app_settings_table.dart';
import 'tables/cloud_account_bindings_table.dart';
import 'tables/common_columns.dart';
import 'tables/goals_table.dart';
import 'tables/health_records_table.dart';
import 'tables/installation_info_table.dart';
import 'tables/journal_entries_table.dart';
import 'tables/journal_entry_prompt_items_table.dart';
import 'tables/journal_prompt_configurations_table.dart';
import 'tables/journal_prompt_definitions_table.dart';
import 'tables/sync_conflicts_table.dart';
import 'tables/today_records_table.dart';
import 'tables/user_profiles_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    UserProfiles,
    AppSettings,
    Goals,
    TodayRecords,
    JournalEntries,
    JournalPromptConfigurations,
    JournalPromptDefinitions,
    JournalEntryPromptItems,
    HealthRecords,
    AiReports,
    AiReportVersions,
    AiReportFeedback,
    SyncConflicts,
    InstallationInfo,
    CloudAccountBindings,
  ],
  daos: [BootstrapDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase()
    : allowUnboundProfileBootstrapForTesting = false,
      super(openDatabaseConnection());

  AppDatabase.forTesting(super.executor)
    : allowUnboundProfileBootstrapForTesting = true;

  final bool allowUnboundProfileBootstrapForTesting;

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createVersionOneIndexes();
      await _createSyncConflictIndexes();
      await _createAccountBoundaryIndexes();
      await _createJournalPromptIndexes();
      await _createAiReportVersionIndexesAndGuards();
      await _createAiReportFeedbackIndexes();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.alterTable(
          TableMigration(goals, newColumns: [goals.archivedAt]),
        );
        await _createGoalIndexes();
      } else if (from < 3) {
        await migrator.addColumn(goals, goals.archivedAt);
      }
      if (from < 4) {
        await migrator.createTable(syncConflicts);
        await _createSyncConflictIndexes();
      }
      if (from < 5) {
        await migrator.createTable(installationInfo);
        await migrator.createTable(cloudAccountBindings);
        if (from >= 4) {
          await migrator.alterTable(TableMigration(syncConflicts));
          await _createSyncConflictIndexes();
        }
        await _migrateInstallationInfo();
        await _supersedeUnhydratedLegacyConflicts();
        await _createAccountBoundaryIndexes();
      }
      if (from == 5) {
        await migrator.addColumn(
          cloudAccountBindings,
          cloudAccountBindings.bindingOrigin,
        );
        await migrator.addColumn(
          cloudAccountBindings,
          cloudAccountBindings.syncEligibilityStatus,
        );
        await migrator.addColumn(
          cloudAccountBindings,
          cloudAccountBindings.ownershipConfirmedAt,
        );
        await customStatement(
          'UPDATE cloud_account_bindings '
          'SET ownership_confirmed_at = created_at '
          'WHERE ownership_confirmed_at IS NULL',
        );
        await _createAccountBoundaryIndexes();
      }
      if (from >= 5 && from < 7) {
        await migrator.addColumn(
          cloudAccountBindings,
          cloudAccountBindings.verificationStatus,
        );
        await migrator.addColumn(
          cloudAccountBindings,
          cloudAccountBindings.verificationTime,
        );
        await migrator.addColumn(
          cloudAccountBindings,
          cloudAccountBindings.verificationMethod,
        );
        await migrator.addColumn(
          cloudAccountBindings,
          cloudAccountBindings.verificationReason,
        );
        await customStatement(
          'UPDATE cloud_account_bindings '
          "SET verification_status = 'verified', "
          'verification_time = COALESCE(ownership_confirmed_at, created_at), '
          "verification_method = 'account_space_creation', "
          "verification_reason = 'all_evidence_matches_current_user' "
          "WHERE sync_eligibility_status = 'ready'",
        );
        await customStatement(
          'UPDATE cloud_account_bindings '
          "SET verification_status = 'not_verified', "
          'verification_time = NULL, '
          'verification_method = NULL, '
          'verification_reason = NULL '
          "WHERE sync_eligibility_status = 'legacy_review_required'",
        );
        await migrator.alterTable(TableMigration(cloudAccountBindings));
        await _createAccountBoundaryIndexes();
      }
      if (from < 8 && from >= 4) {
        if (!await _columnExists('sync_conflicts', 'remote_record_id')) {
          await migrator.addColumn(syncConflicts, syncConflicts.remoteRecordId);
        }
      }
      if (from < 9) {
        await migrator.alterTable(TableMigration(syncConflicts));
        await _createSyncConflictIndexes();
        await migrator.createTable(journalPromptConfigurations);
        await migrator.createTable(journalPromptDefinitions);
        await migrator.createTable(journalEntryPromptItems);
        await _createJournalPromptIndexes();
        await _backfillJournalPromptSystem();
      }
      if (from < 10) {
        await migrator.alterTable(
          TableMigration(
            aiReports,
            newColumns: [
              aiReports.title,
              aiReports.generationSource,
              aiReports.sensitivity,
              aiReports.quality,
              aiReports.currentVersion,
            ],
          ),
        );
        await migrator.createTable(aiReportVersions);
        await _backfillAiReportVersions();
        await _createAiReportIndexes();
        await _createAiReportVersionIndexesAndGuards();
      }
      if (from < 11) {
        await migrator.alterTable(TableMigration(syncConflicts));
        await _createSyncConflictIndexes();
      }
      if (from < 12) {
        await migrator.createTable(aiReportFeedback);
        await _createAiReportFeedbackIndexes();
      }
      if (from < 13) {
        await migrator.alterTable(
          TableMigration(
            todayRecords,
            newColumns: [
              todayRecords.wellbeingScoreScale,
              todayRecords.moodDescription,
              todayRecords.energyDescription,
            ],
          ),
        );
        await migrator.alterTable(
          TableMigration(
            healthRecords,
            newColumns: [
              healthRecords.physicalStateScoreScale,
              healthRecords.physicalStateDescription,
            ],
          ),
        );
        await _createTodayAndHealthIndexes();
      }
    },
    beforeOpen: (details) async {
      if (details.versionBefore case final previous?
          when previous > details.versionNow) {
        throw StateError(
          'Database downgrade is not supported: '
          '$previous -> ${details.versionNow}',
        );
      }
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createVersionOneIndexes() async {
    // Drift's DSL does not directly model the partial unique indexes used to
    // keep soft-deleted rows out of uniqueness checks, so schema v1 creates
    // those indexes with explicit, version-controlled SQL.
    for (final statement in _versionOneIndexes) {
      await customStatement(statement);
    }
    await _createGoalIndexes();
  }

  Future<void> _createGoalIndexes() async {
    for (final statement in _goalIndexes) {
      await customStatement(statement);
    }
  }

  Future<void> _createTodayAndHealthIndexes() async {
    for (final statement in _todayAndHealthIndexes) {
      await customStatement(statement);
    }
  }

  Future<void> _createSyncConflictIndexes() async {
    for (final statement in _syncConflictIndexes) {
      await customStatement(statement);
    }
  }

  Future<void> _createAccountBoundaryIndexes() async {
    for (final statement in _accountBoundaryIndexes) {
      await customStatement(statement);
    }
  }

  Future<void> _createJournalPromptIndexes() async {
    for (final statement in _journalPromptIndexes) {
      await customStatement(statement);
    }
  }

  Future<void> _createAiReportVersionIndexesAndGuards() async {
    for (final statement in _aiReportVersionStatements) {
      await customStatement(statement);
    }
  }

  Future<void> _createAiReportIndexes() async {
    for (final statement in _aiReportIndexes) {
      await customStatement(statement);
    }
  }

  Future<void> _createAiReportFeedbackIndexes() async {
    for (final statement in _aiReportFeedbackIndexes) {
      await customStatement(statement);
    }
  }

  Future<void> _backfillAiReportVersions() async {
    await customStatement('''
INSERT INTO ai_report_versions (
  id, report_id, version, status, generation_source, model_metadata_json,
  content, sensitivity, quality, error_code, completed_at, created_at,
  updated_at
)
SELECT
  lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' ||
  substr(lower(hex(randomblob(2))), 2) || '-8' ||
  substr(lower(hex(randomblob(2))), 2) || '-' || lower(hex(randomblob(6))),
  id, 1, report_status, 'legacy', NULL, report_content, 'high', 'unknown',
  CASE WHEN report_status = 'failed'
    THEN COALESCE(NULLIF(trim(error_code), ''), 'unknown')
    ELSE NULL END,
  generated_at, created_at, updated_at
FROM ai_reports
WHERE report_status IN ('completed', 'failed')
''');
    await customStatement(
      "UPDATE ai_reports SET current_version = 1, "
      "title = CASE report_type "
      "WHEN 'daily_insight' THEN '每日洞察' "
      "WHEN 'weekly_report' THEN '每周回顾' "
      "WHEN 'monthly_reflection' THEN '月度复盘' "
      "WHEN 'tomorrow_suggestion' THEN '明日建议' "
      "WHEN 'trend_explanation' THEN '趋势说明' "
      "ELSE 'AI 报告' END "
      "WHERE report_status IN ('completed', 'failed')",
    );
  }

  Future<void> _backfillJournalPromptSystem() async {
    final users = await customSelect(
      'SELECT id, created_at, updated_at FROM user_profiles',
    ).get();
    final fallbackInstallation = await customSelect(
      'SELECT installation_id FROM installation_info LIMIT 1',
    ).getSingleOrNull();

    for (final user in users) {
      final userId = user.read<String>('id');
      final createdAt = user.read<int>('created_at');
      final updatedAt = user.read<int>('updated_at');
      final settings = await customSelect(
        'SELECT local_installation_id FROM app_settings '
        'WHERE user_id = ? LIMIT 1',
        variables: [Variable.withString(userId)],
      ).getSingleOrNull();
      final originDeviceId =
          settings?.read<String>('local_installation_id') ??
          fallbackInstallation?.read<String>('installation_id');
      final configurationId = deterministicUuid(
        'journal-prompt-configuration:$userId:default',
      );

      await customStatement(
        'INSERT OR IGNORE INTO journal_prompt_configurations '
        '(id, user_id, logical_key, configuration_version, created_at, '
        'updated_at, sync_status, server_version, last_synced_at, '
        'origin_device_id, deleted_at) '
        "VALUES (?, ?, 'default', 1, ?, ?, 'local_only', NULL, NULL, ?, NULL)",
        [configurationId, userId, createdAt, updatedAt, originDeviceId],
      );

      for (final prompt in JournalPromptCatalog.prompts) {
        final promptId = deterministicUuid(
          'journal-prompt:$configurationId:${prompt.stableKey}',
        );
        await customStatement(
          'INSERT OR IGNORE INTO journal_prompt_definitions '
          '(id, configuration_id, stable_key, prompt_source, question_text, '
          'helper_text, response_kind, display_order, is_enabled, '
          'prompt_version, created_at, updated_at, deleted_at) '
          "VALUES (?, ?, ?, 'system', ?, ?, 'long_text', ?, 1, 1, ?, ?, NULL)",
          [
            promptId,
            configurationId,
            prompt.stableKey,
            prompt.questionText,
            prompt.helperText,
            prompt.displayOrder,
            createdAt,
            updatedAt,
          ],
        );
      }
    }

    final entries = await customSelect(
      'SELECT id, user_id, created_at, updated_at, '
      'most_important_accomplishment, most_draining_event, emotion_source, '
      'learning, tomorrow_adjustment FROM journal_entries',
    ).get();
    for (final entry in entries) {
      final entryId = entry.read<String>('id');
      final userId = entry.read<String>('user_id');
      final configurationId = deterministicUuid(
        'journal-prompt-configuration:$userId:default',
      );
      final answers = <String, String?>{
        JournalPromptCatalog.accomplishmentKey: entry.readNullable<String>(
          'most_important_accomplishment',
        ),
        JournalPromptCatalog.drainingEventKey: entry.readNullable<String>(
          'most_draining_event',
        ),
        JournalPromptCatalog.emotionSourceKey: entry.readNullable<String>(
          'emotion_source',
        ),
        JournalPromptCatalog.learningKey: entry.readNullable<String>(
          'learning',
        ),
        JournalPromptCatalog.tomorrowAdjustmentKey: entry.readNullable<String>(
          'tomorrow_adjustment',
        ),
      };
      for (final prompt in JournalPromptCatalog.prompts) {
        final promptId = deterministicUuid(
          'journal-prompt:$configurationId:${prompt.stableKey}',
        );
        final itemId = deterministicUuid(
          'journal-entry-prompt-item:$entryId:${prompt.stableKey}:1',
        );
        await customStatement(
          'INSERT OR IGNORE INTO journal_entry_prompt_items '
          '(id, journal_entry_id, source_prompt_id, source_prompt_stable_key, '
          'source_prompt_version, prompt_source, question_text_snapshot, '
          'helper_text_snapshot, response_kind, display_order, answer_text, '
          'created_at, updated_at) '
          "VALUES (?, ?, ?, ?, 1, 'system', ?, ?, 'long_text', ?, ?, ?, ?)",
          [
            itemId,
            entryId,
            promptId,
            prompt.stableKey,
            prompt.questionText,
            prompt.helperText,
            prompt.displayOrder,
            answers[prompt.stableKey],
            entry.read<int>('created_at'),
            entry.read<int>('updated_at'),
          ],
        );
      }
    }
  }

  Future<void> _migrateInstallationInfo() async {
    await customStatement(
      'INSERT OR IGNORE INTO installation_info '
      '(singleton_id, installation_id, created_at, platform) '
      'SELECT 1, settings.local_installation_id, settings.created_at, NULL '
      'FROM app_settings AS settings '
      'LEFT JOIN user_profiles AS profile ON profile.id = settings.user_id '
      'ORDER BY '
      'CASE WHEN profile.is_active = 1 AND profile.deleted_at IS NULL '
      'THEN 0 ELSE 1 END, settings.created_at ASC '
      'LIMIT 1',
    );
    await customStatement(
      'UPDATE app_settings '
      'SET local_installation_id = ('
      'SELECT installation_id FROM installation_info WHERE singleton_id = 1'
      ') '
      'WHERE EXISTS ('
      'SELECT 1 FROM installation_info WHERE singleton_id = 1'
      ')',
    );
  }

  Future<void> _supersedeUnhydratedLegacyConflicts() {
    return customStatement(
      "UPDATE sync_conflicts SET "
      "resolution_status = 'superseded_by_account_isolation_migration', "
      'resolved_at = last_seen_at '
      "WHERE resolution_status = 'awaiting_remote_snapshot' "
      'AND resolved_at IS NULL',
    );
  }

  Future<bool> _columnExists(String tableName, String columnName) async {
    final columns = await customSelect('PRAGMA table_info($tableName)').get();
    return columns.any((row) => row.read<String>('name') == columnName);
  }
}

const _versionOneIndexes = <String>[
  'CREATE UNIQUE INDEX user_profiles_one_active '
      'ON user_profiles (is_active) '
      'WHERE is_active = 1 AND deleted_at IS NULL',
  'CREATE INDEX user_profiles_sync_status_updated_at '
      'ON user_profiles (sync_status, updated_at)',
  'CREATE UNIQUE INDEX today_records_user_date_active '
      'ON today_records (user_id, record_date) '
      'WHERE deleted_at IS NULL',
  'CREATE INDEX today_records_user_date_desc '
      'ON today_records (user_id, record_date DESC)',
  'CREATE INDEX today_records_sync_status_updated_at '
      'ON today_records (sync_status, updated_at)',
  'CREATE UNIQUE INDEX journal_entries_user_date_active '
      'ON journal_entries (user_id, entry_date) '
      'WHERE deleted_at IS NULL',
  'CREATE UNIQUE INDEX journal_entries_today_record_active '
      'ON journal_entries (today_record_id) '
      'WHERE today_record_id IS NOT NULL AND deleted_at IS NULL',
  'CREATE INDEX journal_entries_user_date_desc '
      'ON journal_entries (user_id, entry_date DESC)',
  'CREATE UNIQUE INDEX health_records_user_date_active '
      'ON health_records (user_id, record_date) '
      'WHERE deleted_at IS NULL',
  'CREATE UNIQUE INDEX health_records_today_record_active '
      'ON health_records (today_record_id) '
      'WHERE today_record_id IS NOT NULL AND deleted_at IS NULL',
  'CREATE INDEX health_records_user_date_desc '
      'ON health_records (user_id, record_date DESC)',
  'CREATE UNIQUE INDEX health_records_external_source '
      'ON health_records (data_source, source_record_id) '
      'WHERE source_record_id IS NOT NULL AND deleted_at IS NULL',
  'CREATE INDEX ai_reports_user_type_period '
      'ON ai_reports (user_id, report_type, period_end_date DESC)',
  'CREATE INDEX ai_reports_input_deduplication '
      'ON ai_reports '
      '(user_id, report_type, period_start_date, period_end_date, input_hash)',
  'CREATE INDEX ai_reports_status_requested_at '
      'ON ai_reports (report_status, requested_at)',
];

const _goalIndexes = <String>[
  'CREATE INDEX IF NOT EXISTS goals_user_parent_sort_order '
      'ON goals (user_id, parent_goal_id, sort_order)',
  'CREATE INDEX IF NOT EXISTS goals_user_level_status '
      'ON goals (user_id, goal_level, status)',
  'CREATE INDEX IF NOT EXISTS goals_user_target_date '
      'ON goals (user_id, target_date)',
];

const _todayAndHealthIndexes = <String>[
  'CREATE UNIQUE INDEX IF NOT EXISTS today_records_user_date_active '
      'ON today_records (user_id, record_date) WHERE deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS today_records_user_date_desc '
      'ON today_records (user_id, record_date DESC)',
  'CREATE INDEX IF NOT EXISTS today_records_sync_status_updated_at '
      'ON today_records (sync_status, updated_at)',
  'CREATE UNIQUE INDEX IF NOT EXISTS health_records_user_date_active '
      'ON health_records (user_id, record_date) WHERE deleted_at IS NULL',
  'CREATE UNIQUE INDEX IF NOT EXISTS health_records_today_record_active '
      'ON health_records (today_record_id) '
      'WHERE today_record_id IS NOT NULL AND deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS health_records_user_date_desc '
      'ON health_records (user_id, record_date DESC)',
  'CREATE UNIQUE INDEX IF NOT EXISTS health_records_external_source '
      'ON health_records (data_source, source_record_id) '
      'WHERE source_record_id IS NOT NULL AND deleted_at IS NULL',
];

const _syncConflictIndexes = <String>[
  'CREATE INDEX IF NOT EXISTS sync_conflicts_user_status_detected '
      'ON sync_conflicts '
      '(local_user_id, resolution_status, detected_at DESC)',
  'CREATE INDEX IF NOT EXISTS sync_conflicts_endpoint_user_entity '
      'ON sync_conflicts (endpoint_key, cloud_user_id, entity_type)',
  'CREATE INDEX IF NOT EXISTS sync_conflicts_entity_record '
      'ON sync_conflicts (entity_type, record_id)',
  'CREATE UNIQUE INDEX IF NOT EXISTS sync_conflicts_one_active '
      'ON sync_conflicts '
      '(endpoint_key, cloud_user_id, entity_type, record_id) '
      'WHERE resolved_at IS NULL',
];

const _accountBoundaryIndexes = <String>[
  'CREATE INDEX IF NOT EXISTS cloud_account_bindings_status_last_used '
      'ON cloud_account_bindings (status, last_used_at DESC)',
];

const _journalPromptIndexes = <String>[
  'CREATE UNIQUE INDEX IF NOT EXISTS '
      'journal_prompt_configurations_user_default_active '
      'ON journal_prompt_configurations (user_id, logical_key) '
      'WHERE deleted_at IS NULL',
  'CREATE UNIQUE INDEX IF NOT EXISTS '
      'journal_prompt_definitions_system_key_active '
      'ON journal_prompt_definitions (configuration_id, stable_key) '
      'WHERE stable_key IS NOT NULL AND deleted_at IS NULL',
  'CREATE INDEX IF NOT EXISTS journal_prompt_definitions_order '
      'ON journal_prompt_definitions '
      '(configuration_id, is_enabled DESC, display_order, id)',
  'CREATE INDEX IF NOT EXISTS journal_entry_prompt_items_entry_order '
      'ON journal_entry_prompt_items (journal_entry_id, display_order, id)',
  'CREATE UNIQUE INDEX IF NOT EXISTS '
      'journal_entry_prompt_items_source_snapshot '
      'ON journal_entry_prompt_items '
      '(journal_entry_id, source_prompt_id, source_prompt_version) '
      'WHERE source_prompt_id IS NOT NULL',
];

const _aiReportVersionStatements = <String>[
  'CREATE INDEX IF NOT EXISTS ai_report_versions_report_version '
      'ON ai_report_versions (report_id, version DESC)',
  'CREATE TRIGGER IF NOT EXISTS ai_report_versions_no_update '
      'BEFORE UPDATE ON ai_report_versions BEGIN '
      "SELECT RAISE(ABORT, 'AI report versions are immutable'); END",
  'CREATE TRIGGER IF NOT EXISTS ai_report_versions_no_delete '
      'BEFORE DELETE ON ai_report_versions BEGIN '
      "SELECT RAISE(ABORT, 'AI report versions are immutable'); END",
];

const _aiReportIndexes = <String>[
  'CREATE INDEX IF NOT EXISTS ai_reports_user_type_period '
      'ON ai_reports (user_id, report_type, period_end_date DESC)',
  'CREATE INDEX IF NOT EXISTS ai_reports_input_deduplication '
      'ON ai_reports '
      '(user_id, report_type, period_start_date, period_end_date, input_hash)',
  'CREATE INDEX IF NOT EXISTS ai_reports_status_requested_at '
      'ON ai_reports (report_status, requested_at)',
];

const _aiReportFeedbackIndexes = <String>[
  'CREATE INDEX IF NOT EXISTS ai_report_feedback_user_updated '
      'ON ai_report_feedback (user_id, updated_at DESC)',
  'CREATE INDEX IF NOT EXISTS ai_report_feedback_pending '
      'ON ai_report_feedback (user_id, sync_status, updated_at)',
  'CREATE INDEX IF NOT EXISTS ai_report_feedback_report_version '
      'ON ai_report_feedback (report_id, report_version)',
];
