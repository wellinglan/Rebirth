import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/account/domain/account_boundary.dart';
import 'package:rebirth/features/journal/data/journal_conflict_resolution_service_impl.dart';
import 'package:rebirth/features/journal/data/journal_sync_payload_codec.dart';
import 'package:rebirth/features/journal/domain/journal_conflict_resolution_service.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_sync_payload.dart';
import 'package:rebirth/features/plan/data/plan_conflict_resolution_service_impl.dart';
import 'package:rebirth/features/plan/data/plan_sync_payload_codec.dart';
import 'package:rebirth/features/plan/domain/plan_conflict_resolution_service.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_sync_payload.dart';
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
      TodaySyncPayloadCodec(),
      JournalSyncPayloadCodec(),
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
  final session = await ref.watch(authSessionStoreProvider).read();
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

Future<SyncConflictSnapshot?> _loadCurrentSnapshot(
  AppDatabase database,
  SyncConflictRecord record,
  String localUserId,
) async {
  return switch (record.entityType) {
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
    _ => null,
  };
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
  return SyncConflictSnapshot(
    payload: journal.deletedAt == null
        ? JournalSyncPayload(
            entryDate: journal.entryDate,
            timezoneOffsetMinutes: journal.timezoneOffsetMinutes,
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
  if (left is JournalSyncPayload && right is JournalSyncPayload) {
    return const JournalSyncPayloadCodec().canonicalJson(left) ==
        const JournalSyncPayloadCodec().canonicalJson(right);
  }
  if (left is TodaySyncPayload && right is TodaySyncPayload) {
    return const TodaySyncPayloadCodec().canonicalJson(left) ==
        const TodaySyncPayloadCodec().canonicalJson(right);
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
