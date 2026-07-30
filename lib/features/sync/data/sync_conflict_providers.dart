import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/core/utils/date_time_service_provider.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/account/domain/account_boundary.dart';
import 'package:rebirth/features/journal/data/journal_conflict_resolution_service_impl.dart';
import 'package:rebirth/features/journal/data/journal_prompt_conflict_resolution_service.dart';
import 'package:rebirth/features/journal/data/journal_sync_payload_codec.dart';
import 'package:rebirth/features/journal/data/journal_prompt_sync_payload_codec.dart';
import 'package:rebirth/features/journal/domain/journal_conflict_resolution_service.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_entry_prompt_item.dart';
import 'package:rebirth/features/journal/domain/journal_prompt.dart';
import 'package:rebirth/features/journal/domain/journal_prompt_sync_payload.dart';
import 'package:rebirth/features/journal/domain/journal_sync_payload.dart';
import 'package:rebirth/features/health/data/health_conflict_resolution_service_impl.dart';
import 'package:rebirth/features/health/data/health_sync_payload_codec.dart';
import 'package:rebirth/features/health/domain/health_conflict_resolution_service.dart';
import 'package:rebirth/features/health/domain/health_sync_payload.dart';
import 'package:rebirth/features/plan/data/plan_conflict_resolution_service_impl.dart';
import 'package:rebirth/features/plan/data/plan_sync_payload_codec.dart';
import 'package:rebirth/features/plan/domain/plan_conflict_resolution_service.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_sync_payload.dart';
import 'package:rebirth/features/profile/data/profile_conflict_resolution_service_impl.dart';
import 'package:rebirth/features/profile/data/profile_sync_payload_codec.dart';
import 'package:rebirth/features/profile/domain/profile_conflict_resolution_service.dart';
import 'package:rebirth/features/profile/domain/profile_sync_payload.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_repository.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/today/data/today_sync_payload_codec.dart';
import 'package:rebirth/features/today/data/today_conflict_resolution_service_impl.dart';
import 'package:rebirth/features/today/domain/today_conflict_resolution_service.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_sync_payload.dart';

import 'sync_conflict_repository_impl.dart';

final syncConflictRepositoryProvider = Provider<SyncConflictRepository>((ref) {
  return SyncConflictRepositoryImpl(
    ref.watch(appDatabaseProvider),
    payloadCodecs: const [
      ProfileSyncPayloadCodec(),
      TodaySyncPayloadCodec(),
      JournalPromptSyncPayloadCodec(),
      JournalSyncPayloadCodec(),
      HealthSyncPayloadCodec(),
      PlanSyncPayloadCodec(),
    ],
  );
});

final syncConflictScopeProvider = FutureProvider<SyncConflictScope?>((
  ref,
) async {
  final endpoint = ref.watch(effectiveServerEndpointProvider).baseUrl;
  final normalized = ref
      .watch(serverEndpointValidatorProvider)
      .normalize(endpoint);
  final manager = ref.watch(authSessionManagerProvider);
  await manager.initialize();
  final session = manager.state.session;
  if (session == null ||
      session.user.id.trim().isEmpty ||
      session.serverBaseUrl.trim().isEmpty) {
    return null;
  }
  final sessionEndpoint = ref
      .read(serverEndpointValidatorProvider)
      .normalize(session.serverBaseUrl);
  if (sessionEndpoint != normalized) return null;
  final String localUserId;
  try {
    localUserId = await ref
        .watch(accountBoundaryRepositoryProvider)
        .requireActiveScope(endpoint: normalized, cloudUserId: session.user.id);
  } on AccountScopeMismatchException {
    return null;
  } on AccountSyncReviewRequiredException {
    return null;
  }
  return SyncConflictScope(
    localUserId: localUserId,
    endpointKey: normalized,
    cloudUserId: session.user.id,
  );
});

final activeSyncConflictCountProvider = StreamProvider<int>((ref) async* {
  final scope = await ref.watch(syncConflictScopeProvider.future);
  if (scope == null) {
    yield 0;
    return;
  }
  yield* ref
      .watch(syncConflictRepositoryProvider)
      .watchActiveConflictCount(scope);
});

final activeSyncConflictListProvider = FutureProvider<List<SyncConflictRecord>>(
  (ref) async {
    final scope = await ref.watch(syncConflictScopeProvider.future);
    if (scope == null) return const [];
    return ref.watch(syncConflictRepositoryProvider).listActiveConflicts(scope);
  },
);

final syncConflictDetailsProvider =
    FutureProvider.family<SyncConflictDetails, String>((ref, id) async {
      final scope = await ref.watch(syncConflictScopeProvider.future);
      if (scope == null) throw const SyncConflictNotFoundException();
      final record = await ref
          .watch(syncConflictRepositoryProvider)
          .getConflict(scope, id);
      final database = ref.watch(appDatabaseProvider);
      final current = await _loadCurrentSnapshot(
        database,
        record,
        scope.localUserId,
      );
      return SyncConflictDetails(
        record: record,
        currentLocalSnapshot: current,
        localSnapshotChanged:
            current == null ||
            current.updatedAt != record.localSnapshot.updatedAt ||
            !_samePayload(current.payload, record.localSnapshot.payload),
      );
    });

final planConflictResolutionServiceProvider =
    Provider<PlanConflictResolutionService>((ref) {
      return PlanConflictResolutionServiceImpl(
        ref.watch(appDatabaseProvider),
        ref.watch(syncConflictRepositoryProvider),
      );
    });

final profileConflictResolutionServiceProvider =
    Provider<ProfileConflictResolutionService>((ref) {
      return ProfileConflictResolutionServiceImpl(
        ref.watch(appDatabaseProvider),
        ref.watch(syncConflictRepositoryProvider),
        ref.watch(dateTimeServiceProvider),
      );
    });

final todayConflictResolutionServiceProvider =
    Provider<TodayConflictResolutionService>((ref) {
      return TodayConflictResolutionServiceImpl(
        ref.watch(appDatabaseProvider),
        ref.watch(syncConflictRepositoryProvider),
      );
    });

final journalConflictResolutionServiceProvider =
    Provider<JournalConflictResolutionService>((ref) {
      return JournalConflictResolutionServiceImpl(
        ref.watch(appDatabaseProvider),
        ref.watch(syncConflictRepositoryProvider),
      );
    });

final journalPromptConflictResolutionServiceProvider =
    Provider<JournalPromptConflictResolutionService>((ref) {
      return JournalPromptConflictResolutionService(
        ref.watch(appDatabaseProvider),
        ref.watch(syncConflictRepositoryProvider),
      );
    });

final healthConflictResolutionServiceProvider =
    Provider<HealthConflictResolutionService>((ref) {
      return HealthConflictResolutionServiceImpl(
        ref.watch(appDatabaseProvider),
        ref.watch(syncConflictRepositoryProvider),
      );
    });

Future<SyncConflictSnapshot?> _loadCurrentSnapshot(
  AppDatabase database,
  SyncConflictRecord record,
  String localUserId,
) async {
  return switch (record.entityType) {
    SyncEntityType.profile => _loadProfileSnapshot(
      database,
      localUserId,
      record.recordId,
    ),
    SyncEntityType.plan => _loadPlanSnapshot(
      database,
      localUserId,
      record.recordId,
    ),
    SyncEntityType.today => _loadTodaySnapshot(
      database,
      localUserId,
      record.recordId,
    ),
    SyncEntityType.journal => _loadJournalSnapshot(
      database,
      localUserId,
      record.recordId,
    ),
    SyncEntityType.journalPromptConfiguration =>
      _loadJournalPromptConfigurationSnapshot(
        database,
        localUserId,
        record.recordId,
      ),
    SyncEntityType.health => _loadHealthSnapshot(
      database,
      localUserId,
      record.recordId,
    ),
  };
}

Future<SyncConflictSnapshot?> _loadProfileSnapshot(
  AppDatabase database,
  String localUserId,
  String _,
) async {
  final profile =
      await (database.select(database.userProfiles)..where(
            (row) =>
                row.id.equals(localUserId) &
                row.isActive.equals(true) &
                row.deletedAt.isNull(),
          ))
          .getSingleOrNull();
  if (profile == null) return null;
  return SyncConflictSnapshot(
    payload: ProfileSyncPayload(
      displayName: profile.displayName,
      growthFocus: profile.growthFocus,
      timezoneId: profile.timezoneId,
      updatedAt: profile.updatedAt,
    ),
    updatedAt: profile.updatedAt,
    deletedAt: profile.deletedAt,
    serverVersion: profile.serverVersion,
    originDeviceId: profile.originDeviceId,
  );
}

Future<SyncConflictSnapshot?> _loadJournalPromptConfigurationSnapshot(
  AppDatabase database,
  String localUserId,
  String recordId,
) async {
  final configuration =
      await (database.select(database.journalPromptConfigurations)..where(
            (row) => row.userId.equals(localUserId) & row.id.equals(recordId),
          ))
          .getSingleOrNull();
  if (configuration == null) return null;
  final rows =
      await (database.select(database.journalPromptDefinitions)
            ..where((row) => row.configurationId.equals(configuration.id))
            ..orderBy([
              (row) => OrderingTerm.asc(row.displayOrder),
              (row) => OrderingTerm.asc(row.id),
            ]))
          .get();
  return SyncConflictSnapshot(
    payload: configuration.deletedAt == null
        ? JournalPromptConfigurationSyncPayload(
            logicalKey: configuration.logicalKey,
            configurationVersion: configuration.configurationVersion,
            createdAt: configuration.createdAt,
            prompts: [
              for (final row in rows)
                JournalPromptDefinition(
                  id: row.id,
                  configurationId: configuration.id,
                  stableKey: row.stableKey,
                  source: JournalPromptSource.fromWireName(row.promptSource),
                  questionText: row.questionText,
                  helperText: row.helperText,
                  responseKind: JournalResponseKind.fromWireName(
                    row.responseKind,
                  ),
                  displayOrder: row.displayOrder,
                  isEnabled: row.isEnabled,
                  promptVersion: row.promptVersion,
                  createdAt: row.createdAt,
                  updatedAt: row.updatedAt,
                  deletedAt: row.deletedAt,
                ),
            ],
          )
        : null,
    updatedAt: configuration.updatedAt,
    deletedAt: configuration.deletedAt,
    serverVersion: configuration.serverVersion,
    originDeviceId: configuration.originDeviceId,
  );
}

Future<SyncConflictSnapshot?> _loadHealthSnapshot(
  AppDatabase database,
  String localUserId,
  String recordId,
) async {
  final health =
      await (database.select(database.healthRecords)..where(
            (row) => row.userId.equals(localUserId) & row.id.equals(recordId),
          ))
          .getSingleOrNull();
  if (health == null) return null;
  return SyncConflictSnapshot(
    payload: health.deletedAt == null
        ? HealthSyncPayload(
            recordDate: health.recordDate,
            timezoneOffsetMinutes: health.timezoneOffsetMinutes,
            sleepDurationMinutes: health.sleepDurationMinutes,
            weightKg: health.weightKg,
            waterIntakeMl: health.waterIntakeMl,
            exerciseType: health.exerciseType,
            exerciseDurationMinutes: health.exerciseDurationMinutes,
            physicalStateScore: health.physicalStateScore,
            note: health.note,
            dataSource: health.dataSource,
            sourceRecordId: health.sourceRecordId,
            createdAt: health.createdAt,
          )
        : null,
    updatedAt: health.updatedAt,
    deletedAt: health.deletedAt,
    serverVersion: health.serverVersion,
    originDeviceId: health.originDeviceId,
  );
}

Future<SyncConflictSnapshot?> _loadJournalSnapshot(
  AppDatabase database,
  String localUserId,
  String recordId,
) async {
  final journal =
      await (database.select(database.journalEntries)..where(
            (row) => row.userId.equals(localUserId) & row.id.equals(recordId),
          ))
          .getSingleOrNull();
  if (journal == null) return null;
  final promptRows =
      await (database.select(database.journalEntryPromptItems)
            ..where((row) => row.journalEntryId.equals(journal.id))
            ..orderBy([
              (row) => OrderingTerm.asc(row.displayOrder),
              (row) => OrderingTerm.asc(row.id),
            ]))
          .get();
  return SyncConflictSnapshot(
    payload: journal.deletedAt == null
        ? JournalSyncPayload(
            entryDate: journal.entryDate,
            timezoneOffsetMinutes: journal.timezoneOffsetMinutes,
            promptItems: [
              for (final item in promptRows)
                JournalEntryPromptItem(
                  id: item.id,
                  sourcePromptId: item.sourcePromptId,
                  sourcePromptStableKey: item.sourcePromptStableKey,
                  sourcePromptVersion: item.sourcePromptVersion,
                  promptSource: JournalPromptSource.fromWireName(
                    item.promptSource,
                  ),
                  questionTextSnapshot: item.questionTextSnapshot,
                  helperTextSnapshot: item.helperTextSnapshot,
                  responseKind: JournalResponseKind.fromWireName(
                    item.responseKind,
                  ),
                  displayOrder: item.displayOrder,
                  answerText: item.answerText,
                  createdAt: item.createdAt,
                  updatedAt: item.updatedAt,
                ),
            ],
            mostImportantAccomplishment: journal.mostImportantAccomplishment,
            mostDrainingEvent: journal.mostDrainingEvent,
            emotionSource: journal.emotionSource,
            learning: journal.learning,
            tomorrowAdjustment: journal.tomorrowAdjustment,
            status: switch (journal.entryStatus) {
              'draft' => JournalEntryStatus.draft,
              'completed' => JournalEntryStatus.completed,
              _ => throw StateError('Unknown Journal status.'),
            },
            createdAt: journal.createdAt,
          )
        : null,
    updatedAt: journal.updatedAt,
    deletedAt: journal.deletedAt,
    serverVersion: journal.serverVersion,
    originDeviceId: journal.originDeviceId,
  );
}

Future<SyncConflictSnapshot?> _loadPlanSnapshot(
  AppDatabase database,
  String localUserId,
  String recordId,
) async {
  final goal =
      await (database.select(database.goals)..where(
            (row) => row.userId.equals(localUserId) & row.id.equals(recordId),
          ))
          .getSingleOrNull();
  if (goal == null) return null;
  return SyncConflictSnapshot(
    payload: goal.deletedAt == null
        ? PlanSyncPayload(
            parentGoalId: goal.parentGoalId,
            title: goal.title,
            description: goal.description,
            goalLevel: planGoalLevelFromDatabase(goal.goalLevel),
            status: planGoalStatusFromDatabase(goal.status),
            startDate: goal.startDate,
            targetDate: goal.targetDate,
            completedAt: goal.completedAt,
            archivedAt: goal.archivedAt,
            sortOrder: goal.sortOrder,
            createdAt: goal.createdAt,
          )
        : null,
    updatedAt: goal.updatedAt,
    deletedAt: goal.deletedAt,
    serverVersion: goal.serverVersion,
    originDeviceId: goal.originDeviceId,
  );
}

Future<SyncConflictSnapshot?> _loadTodaySnapshot(
  AppDatabase database,
  String localUserId,
  String recordId,
) async {
  final today =
      await (database.select(database.todayRecords)..where(
            (row) => row.userId.equals(localUserId) & row.id.equals(recordId),
          ))
          .getSingleOrNull();
  if (today == null) return null;
  return SyncConflictSnapshot(
    payload: today.deletedAt == null
        ? TodaySyncPayload(
            recordDate: today.recordDate,
            timezoneOffsetMinutes: today.timezoneOffsetMinutes,
            priority1: today.priority1,
            priority1Completed: today.priority1Completed,
            priority1GoalId: today.priority1GoalId,
            priority2: today.priority2,
            priority2Completed: today.priority2Completed,
            priority2GoalId: today.priority2GoalId,
            priority3: today.priority3,
            priority3Completed: today.priority3Completed,
            priority3GoalId: today.priority3GoalId,
            moodScore: today.moodScore,
            energyScore: today.energyScore,
            researchMinutes: today.researchMinutes,
            learningMinutes: today.learningMinutes,
            dailyNote: today.dailyNote,
            status: switch (today.recordStatus) {
              'draft' => TodayRecordStatus.draft,
              'completed' => TodayRecordStatus.completed,
              _ => throw StateError('Unknown Today status.'),
            },
            createdAt: today.createdAt,
          )
        : null,
    updatedAt: today.updatedAt,
    deletedAt: today.deletedAt,
    serverVersion: today.serverVersion,
    originDeviceId: today.originDeviceId,
  );
}

bool _samePayload(Object? left, Object? right) {
  if (left is ProfileSyncPayload && right is ProfileSyncPayload) {
    return left.displayName == right.displayName &&
        left.growthFocus == right.growthFocus &&
        left.timezoneId == right.timezoneId &&
        left.updatedAt == right.updatedAt;
  }
  if (left is JournalPromptConfigurationSyncPayload &&
      right is JournalPromptConfigurationSyncPayload) {
    return const JournalPromptSyncPayloadCodec().canonicalJson(left) ==
        const JournalPromptSyncPayloadCodec().canonicalJson(right);
  }
  if (left is JournalSyncPayload && right is JournalSyncPayload) {
    return const JournalSyncPayloadCodec().canonicalJson(left) ==
        const JournalSyncPayloadCodec().canonicalJson(right);
  }
  if (left is TodaySyncPayload && right is TodaySyncPayload) {
    return const TodaySyncPayloadCodec().canonicalJson(left) ==
        const TodaySyncPayloadCodec().canonicalJson(right);
  }
  if (left is HealthSyncPayload && right is HealthSyncPayload) {
    return const HealthSyncPayloadCodec().canonicalJson(left) ==
        const HealthSyncPayloadCodec().canonicalJson(right);
  }
  if (left is! PlanSyncPayload || right is! PlanSyncPayload) {
    return left == null && right == null;
  }
  return left.parentGoalId == right.parentGoalId &&
      left.title == right.title &&
      left.description == right.description &&
      left.goalLevel == right.goalLevel &&
      left.status == right.status &&
      left.startDate == right.startDate &&
      left.targetDate == right.targetDate &&
      left.completedAt == right.completedAt &&
      left.archivedAt == right.archivedAt &&
      left.sortOrder == right.sortOrder &&
      left.createdAt == right.createdAt;
}
