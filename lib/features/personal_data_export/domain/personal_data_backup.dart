import 'dart:collection';

abstract interface class PersonalDataBackupRecord {
  Map<String, Object?> toJson();
}

final class ProfileBackupRecord implements PersonalDataBackupRecord {
  const ProfileBackupRecord({
    required this.displayName,
    required this.growthFocus,
    required this.timezoneId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String? displayName;
  final String? growthFocus;
  final String timezoneId;
  final String createdAt;
  final String updatedAt;

  @override
  Map<String, Object?> toJson() => {
    'display_name': displayName,
    'growth_focus': growthFocus,
    'timezone_id': timezoneId,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}

final class PlanGoalBackupRecord implements PersonalDataBackupRecord {
  const PlanGoalBackupRecord({
    required this.id,
    required this.parentGoalId,
    required this.title,
    required this.description,
    required this.goalLevel,
    required this.status,
    required this.startDate,
    required this.targetDate,
    required this.completedAt,
    required this.archivedAt,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final String? parentGoalId;
  final String title;
  final String? description;
  final String goalLevel;
  final String status;
  final String? startDate;
  final String? targetDate;
  final String? completedAt;
  final String? archivedAt;
  final int sortOrder;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'parent_goal_id': parentGoalId,
    'title': title,
    'description': description,
    'goal_level': goalLevel,
    'status': status,
    'start_date': startDate,
    'target_date': targetDate,
    'completed_at': completedAt,
    'archived_at': archivedAt,
    'sort_order': sortOrder,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
  };
}

final class TodayPriorityBackupRecord implements PersonalDataBackupRecord {
  const TodayPriorityBackupRecord({
    required this.slot,
    required this.text,
    required this.completed,
    required this.goalId,
  });

  final int slot;
  final String? text;
  final bool completed;
  final String? goalId;

  @override
  Map<String, Object?> toJson() => {
    'slot': slot,
    'text': text,
    'completed': completed,
    'goal_id': goalId,
  };
}

final class TodayBackupRecord implements PersonalDataBackupRecord {
  TodayBackupRecord({
    required this.id,
    required this.recordDate,
    required this.timezoneOffsetMinutes,
    required List<TodayPriorityBackupRecord> priorities,
    required this.moodScore,
    this.moodDescription,
    required this.energyScore,
    this.energyDescription,
    required this.researchMinutes,
    this.researchDescription,
    required this.learningMinutes,
    this.learningDescription,
    required this.dailyNote,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  }) : priorities = UnmodifiableListView(priorities);

  final String id;
  final String recordDate;
  final int timezoneOffsetMinutes;
  final List<TodayPriorityBackupRecord> priorities;
  final int? moodScore;
  final String? moodDescription;
  final int? energyScore;
  final String? energyDescription;
  final int? researchMinutes;
  final String? researchDescription;
  final int? learningMinutes;
  final String? learningDescription;
  final String? dailyNote;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'record_date': recordDate,
    'timezone_offset_minutes': timezoneOffsetMinutes,
    'priorities': priorities.map((item) => item.toJson()).toList(),
    'mood_score': moodScore,
    'mood_description': moodDescription,
    'energy_score': energyScore,
    'energy_description': energyDescription,
    'wellbeing_score_scale': 10,
    'research_minutes': researchMinutes,
    'research_description': researchDescription,
    'learning_minutes': learningMinutes,
    'learning_description': learningDescription,
    'daily_note': dailyNote,
    'status': status,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
  };
}

final class JournalPromptItemBackupRecord implements PersonalDataBackupRecord {
  const JournalPromptItemBackupRecord({
    required this.id,
    required this.sourcePromptId,
    required this.sourcePromptStableKey,
    required this.sourcePromptVersion,
    required this.promptSource,
    required this.questionTextSnapshot,
    required this.helperTextSnapshot,
    required this.responseKind,
    required this.displayOrder,
    required this.answerText,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? sourcePromptId;
  final String? sourcePromptStableKey;
  final int sourcePromptVersion;
  final String promptSource;
  final String questionTextSnapshot;
  final String? helperTextSnapshot;
  final String responseKind;
  final int displayOrder;
  final String? answerText;
  final String createdAt;
  final String updatedAt;

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'source_prompt_id': sourcePromptId,
    'source_prompt_stable_key': sourcePromptStableKey,
    'source_prompt_version': sourcePromptVersion,
    'prompt_source': promptSource,
    'question_text_snapshot': questionTextSnapshot,
    'helper_text_snapshot': helperTextSnapshot,
    'response_kind': responseKind,
    'display_order': displayOrder,
    'answer_text': answerText,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}

final class JournalBackupRecord implements PersonalDataBackupRecord {
  JournalBackupRecord({
    required this.id,
    required this.todayRecordId,
    required this.entryDate,
    required this.timezoneOffsetMinutes,
    required this.status,
    required List<JournalPromptItemBackupRecord> promptItems,
    required Map<String, String?> legacyCompatibility,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  }) : promptItems = UnmodifiableListView(promptItems),
       legacyCompatibility = UnmodifiableMapView(legacyCompatibility);

  final String id;
  final String? todayRecordId;
  final String entryDate;
  final int timezoneOffsetMinutes;
  final String status;
  final List<JournalPromptItemBackupRecord> promptItems;
  final Map<String, String?> legacyCompatibility;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'today_record_id': todayRecordId,
    'entry_date': entryDate,
    'timezone_offset_minutes': timezoneOffsetMinutes,
    'status': status,
    'prompt_items': promptItems.map((item) => item.toJson()).toList(),
    'legacy_compatibility': legacyCompatibility,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
  };
}

final class JournalPromptDefinitionBackupRecord
    implements PersonalDataBackupRecord {
  const JournalPromptDefinitionBackupRecord({
    required this.id,
    required this.stableKey,
    required this.source,
    required this.questionText,
    required this.helperText,
    required this.responseKind,
    required this.displayOrder,
    required this.isEnabled,
    required this.promptVersion,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final String? stableKey;
  final String source;
  final String questionText;
  final String? helperText;
  final String responseKind;
  final int displayOrder;
  final bool isEnabled;
  final int promptVersion;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'stable_key': stableKey,
    'source': source,
    'question_text': questionText,
    'helper_text': helperText,
    'response_kind': responseKind,
    'display_order': displayOrder,
    'is_enabled': isEnabled,
    'prompt_version': promptVersion,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
  };
}

final class JournalPromptConfigurationBackupRecord
    implements PersonalDataBackupRecord {
  JournalPromptConfigurationBackupRecord({
    required this.id,
    required this.logicalKey,
    required this.configurationVersion,
    required List<JournalPromptDefinitionBackupRecord> definitions,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  }) : definitions = UnmodifiableListView(definitions);

  final String id;
  final String logicalKey;
  final int configurationVersion;
  final List<JournalPromptDefinitionBackupRecord> definitions;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'logical_key': logicalKey,
    'configuration_version': configurationVersion,
    'definitions': definitions.map((item) => item.toJson()).toList(),
    'created_at': createdAt,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
  };
}

final class HealthBackupRecord implements PersonalDataBackupRecord {
  const HealthBackupRecord({
    required this.id,
    required this.todayRecordId,
    required this.recordDate,
    required this.timezoneOffsetMinutes,
    required this.sleepDurationMinutes,
    this.sleepDescription,
    required this.weightKg,
    this.weightDescription,
    required this.waterIntakeMl,
    this.waterDescription,
    required this.exerciseType,
    required this.exerciseDurationMinutes,
    this.exerciseDescription,
    required this.physicalStateScore,
    this.physicalStateDescription,
    required this.note,
    required this.dataSource,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final String? todayRecordId;
  final String recordDate;
  final int timezoneOffsetMinutes;
  final int? sleepDurationMinutes;
  final String? sleepDescription;
  final double? weightKg;
  final String? weightDescription;
  final int? waterIntakeMl;
  final String? waterDescription;
  final String? exerciseType;
  final int? exerciseDurationMinutes;
  final String? exerciseDescription;
  final int? physicalStateScore;
  final String? physicalStateDescription;
  final String? note;
  final String dataSource;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'today_record_id': todayRecordId,
    'record_date': recordDate,
    'timezone_offset_minutes': timezoneOffsetMinutes,
    'sleep_duration_minutes': sleepDurationMinutes,
    'sleep_description': sleepDescription,
    'weight_kg': weightKg,
    'weight_description': weightDescription,
    'water_intake_ml': waterIntakeMl,
    'water_description': waterDescription,
    'exercise_type': exerciseType,
    'exercise_duration_minutes': exerciseDurationMinutes,
    'exercise_description': exerciseDescription,
    'physical_state_score': physicalStateScore,
    'physical_state_description': physicalStateDescription,
    'physical_state_score_scale': 10,
    'note': note,
    'data_source': dataSource,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
  };
}

final class AiReportVersionBackupRecord implements PersonalDataBackupRecord {
  const AiReportVersionBackupRecord({
    required this.version,
    required this.status,
    required this.content,
    required this.sensitivity,
    required this.quality,
    required this.createdAt,
    required this.completedAt,
  });

  final int version;
  final String status;
  final String? content;
  final String sensitivity;
  final String quality;
  final String createdAt;
  final String? completedAt;

  @override
  Map<String, Object?> toJson() => {
    'version': version,
    'status': status,
    'content': content,
    'sensitivity': sensitivity,
    'quality': quality,
    'created_at': createdAt,
    'completed_at': completedAt,
  };
}

final class AiReportBackupRecord implements PersonalDataBackupRecord {
  AiReportBackupRecord({
    required this.id,
    required this.title,
    required this.reportType,
    required this.periodStartDate,
    required this.periodEndDate,
    required this.lifecycleStatus,
    required this.currentVersion,
    required this.currentContent,
    required this.sensitivity,
    required this.quality,
    required this.requestedAt,
    required this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    required List<AiReportVersionBackupRecord> versions,
  }) : versions = UnmodifiableListView(versions);

  final String id;
  final String title;
  final String reportType;
  final String periodStartDate;
  final String periodEndDate;
  final String lifecycleStatus;
  final int currentVersion;
  final String? currentContent;
  final String sensitivity;
  final String quality;
  final String requestedAt;
  final String? completedAt;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final List<AiReportVersionBackupRecord> versions;

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'report_type': reportType,
    'period_start_date': periodStartDate,
    'period_end_date': periodEndDate,
    'lifecycle_status': lifecycleStatus,
    'current_version': currentVersion,
    'current_content': currentContent,
    'sensitivity': sensitivity,
    'quality': quality,
    'requested_at': requestedAt,
    'completed_at': completedAt,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
    'versions': versions.map((item) => item.toJson()).toList(),
  };
}

final class AiReportFeedbackBackupRecord implements PersonalDataBackupRecord {
  AiReportFeedbackBackupRecord({
    required this.reportId,
    required this.reportVersion,
    required this.helpfulness,
    required List<String> reasonCodes,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  }) : reasonCodes = UnmodifiableListView(reasonCodes);

  final String reportId;
  final int reportVersion;
  final String helpfulness;
  final List<String> reasonCodes;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  @override
  Map<String, Object?> toJson() => {
    'report_id': reportId,
    'report_version': reportVersion,
    'helpfulness': helpfulness,
    'reason_codes': reasonCodes,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
  };
}

final class PersonalDataModuleSnapshot {
  PersonalDataModuleSnapshot({
    required this.id,
    required List<PersonalDataBackupRecord> records,
    this.moduleVersion = '1.0',
  }) : records = UnmodifiableListView(records) {
    if (id.trim().isEmpty || moduleVersion.trim().isEmpty) {
      throw ArgumentError('Invalid personal data backup module.');
    }
  }

  final String id;
  final String moduleVersion;
  final List<PersonalDataBackupRecord> records;

  int get recordCount => records.length;

  Map<String, Object?> toJson() => {
    'module_version': moduleVersion,
    'record_count': recordCount,
    'records': records.map((record) => record.toJson()).toList(),
  };
}

final class PersonalDataBackupDocument {
  PersonalDataBackupDocument({
    required this.exportedAt,
    required this.appVersion,
    required this.databaseSchemaVersion,
    required List<PersonalDataModuleSnapshot> modules,
    required this.payloadSha256,
    this.formatId = currentFormatId,
    this.formatVersion = currentFormatVersion,
  }) : modules = UnmodifiableListView(modules) {
    if (formatId != currentFormatId || formatVersion != currentFormatVersion) {
      throw ArgumentError('Unsupported personal data backup format.');
    }
  }

  static const currentFormatId = 'rebirth-personal-data-backup';
  static const currentFormatVersion = '1.0';

  final String formatId;
  final String formatVersion;
  final String exportedAt;
  final String appVersion;
  final int databaseSchemaVersion;
  final List<PersonalDataModuleSnapshot> modules;
  final String payloadSha256;

  int get totalRecordCount =>
      modules.fold(0, (total, module) => total + module.recordCount);

  Map<String, Object?> dataJson() => {
    for (final module in modules) module.id: module.toJson(),
  };

  Map<String, Object?> toJson() => {
    'format_id': formatId,
    'format_version': formatVersion,
    'exported_at': exportedAt,
    'source': {
      'app_version': appVersion,
      'database_schema_version': databaseSchemaVersion,
    },
    'manifest': {
      'account_scope': 'current_authenticated_account',
      'modules': [
        for (final module in modules)
          {
            'id': module.id,
            'module_version': module.moduleVersion,
            'record_count': module.recordCount,
          },
      ],
      'record_counts': {
        for (final module in modules) module.id: module.recordCount,
      },
      'derived_data_excluded': const ['growth', 'personal_data_aggregation'],
      'restore_supported': false,
    },
    'payload_sha256': payloadSha256,
    'data': dataJson(),
  };

  PersonalDataBackupDocument copyWith({String? payloadSha256}) {
    return PersonalDataBackupDocument(
      formatId: formatId,
      formatVersion: formatVersion,
      exportedAt: exportedAt,
      appVersion: appVersion,
      databaseSchemaVersion: databaseSchemaVersion,
      modules: modules,
      payloadSha256: payloadSha256 ?? this.payloadSha256,
    );
  }
}
