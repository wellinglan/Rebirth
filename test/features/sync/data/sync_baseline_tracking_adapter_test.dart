import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/features/sync/data/sync_baseline_tracking_adapter.dart';
import 'package:rebirth/features/sync/data/sync_record_baseline_repository_impl.dart';
import 'package:rebirth/features/sync/domain/sync_conflict.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_entity_adapter.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_merge_policy.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';

void main() {
  late AppDatabase database;
  late String userId;
  late _FakeProfileAdapter delegate;
  late SyncBaselineTrackingAdapter adapter;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final bootstrap = await database.bootstrapDao.bootstrap(
      createUnboundProfile: true,
    );
    userId = bootstrap.activeUserId;
    delegate = _FakeProfileAdapter(database, userId);
    adapter = _trackingAdapter(
      database: database,
      delegate: delegate,
      scope: SyncConflictScope(
        localUserId: userId,
        endpointKey: 'https://sync.example.test',
        cloudUserId: 'cloud-user',
      ),
      snapshot: const SyncConflictSnapshot(
        payload: _ValuePayload('accepted'),
        updatedAt: 10,
        deletedAt: null,
        serverVersion: 4,
        originDeviceId: 'device',
      ),
    );
  });

  tearDown(() => database.close());

  test('accepted push stores a durable account-scoped hash baseline', () async {
    await adapter.acknowledgePush(
      submitted: [_push('accepted')],
      accepted: const [
        SyncAcknowledgement(
          entityType: SyncEntityType.profile,
          recordId: 'profile',
          serverVersion: 4,
        ),
      ],
      conflicts: const [],
      syncedAt: 20,
    );

    final baseline = await SyncRecordBaselineRepositoryImpl(database).read(
      localUserId: userId,
      entityType: SyncEntityType.profile.wireName,
      recordId: userId,
    );
    expect(baseline?.baseServerVersion, 4);
    expect(baseline?.groupHashes.keys, ['value']);
    expect(baseline?.groupHashes.values.single, hasLength(64));
  });

  test('duplicate acknowledgement updates one baseline idempotently', () async {
    for (var index = 0; index < 2; index += 1) {
      await adapter.acknowledgePush(
        submitted: [_push('accepted')],
        accepted: const [
          SyncAcknowledgement(
            entityType: SyncEntityType.profile,
            recordId: 'profile',
            serverVersion: 4,
          ),
        ],
        conflicts: const [],
        syncedAt: 20 + index,
      );
    }

    final rows = await database.select(database.syncRecordBaselines).get();
    expect(rows, hasLength(1));
    expect(rows.single.capturedAt, 21);
  });

  test('stale acknowledgement preserves a newer local pending edit', () async {
    adapter = _trackingAdapter(
      database: database,
      delegate: delegate,
      scope: SyncConflictScope(
        localUserId: userId,
        endpointKey: 'https://sync.example.test',
        cloudUserId: 'cloud-user',
      ),
      snapshot: const SyncConflictSnapshot(
        payload: _ValuePayload('newer local edit'),
        updatedAt: 11,
        deletedAt: null,
        serverVersion: 4,
        originDeviceId: 'device',
      ),
    );

    await adapter.acknowledgePush(
      submitted: [_push('accepted')],
      accepted: const [
        SyncAcknowledgement(
          entityType: SyncEntityType.profile,
          recordId: 'profile',
          serverVersion: 4,
        ),
      ],
      conflicts: const [],
      syncedAt: 20,
    );

    final profile = await (database.select(
      database.userProfiles,
    )..where((row) => row.id.equals(userId))).getSingle();
    expect(profile.syncStatus, 'pending');
  });

  test(
    'baseline failure rolls back delegate acknowledgement metadata',
    () async {
      adapter = _trackingAdapter(
        database: database,
        delegate: delegate,
        scope: const SyncConflictScope(
          localUserId: 'missing-local-user',
          endpointKey: 'https://sync.example.test',
          cloudUserId: 'cloud-user',
        ),
        snapshot: const SyncConflictSnapshot(
          payload: _ValuePayload('accepted'),
          updatedAt: 10,
          deletedAt: null,
          serverVersion: 4,
          originDeviceId: 'device',
        ),
      );

      await expectLater(
        adapter.acknowledgePush(
          submitted: [_push('accepted')],
          accepted: const [
            SyncAcknowledgement(
              entityType: SyncEntityType.profile,
              recordId: 'profile',
              serverVersion: 4,
            ),
          ],
          conflicts: const [],
          syncedAt: 20,
        ),
        throwsA(isA<Exception>()),
      );

      final profile = await (database.select(
        database.userProfiles,
      )..where((row) => row.id.equals(userId))).getSingle();
      expect(profile.syncStatus, 'local_only');
      expect(
        await database.select(database.syncRecordBaselines).get(),
        isEmpty,
      );
    },
  );
}

SyncBaselineTrackingAdapter _trackingAdapter({
  required AppDatabase database,
  required _FakeProfileAdapter delegate,
  required SyncConflictScope scope,
  required SyncConflictSnapshot snapshot,
}) => SyncBaselineTrackingAdapter(
  database: database,
  delegate: delegate,
  baselines: SyncRecordBaselineRepositoryImpl(database),
  policy: MapSyncMergePolicy(
    entityType: SyncEntityType.profile,
    fieldGroups: [
      SyncFieldGroup(id: 'value', keys: const ['value']),
    ],
  ),
  scopeLoader: () async => scope,
  snapshotLoader:
      ({required entityType, required localUserId, required recordId}) async =>
          snapshot,
);

SyncPushItem _push(String value) => SyncPushItem(
  entityType: SyncEntityType.profile,
  operation: SyncOperation.upsert,
  recordId: 'profile',
  payload: _ValuePayload(value),
  updatedAt: 10,
  deletedAt: null,
  originDeviceId: 'device',
  clientVersion: 3,
);

final class _ValuePayload implements SyncEntityPayload {
  const _ValuePayload(this.value);

  final String value;
}

final class _FakeProfileAdapter implements SyncEntityAdapter {
  _FakeProfileAdapter(this.database, this.userId);

  final AppDatabase database;
  final String userId;

  @override
  SyncEntityType get entityType => SyncEntityType.profile;

  @override
  Future<SyncEntityResult> acknowledgePush({
    required List<SyncPushItem> submitted,
    required List<SyncAcknowledgement> accepted,
    required List<SyncConflict> conflicts,
    required int syncedAt,
  }) async {
    await (database.update(
      database.userProfiles,
    )..where((row) => row.id.equals(userId))).write(
      UserProfilesCompanion(
        syncStatus: const Value('synced'),
        serverVersion: Value(accepted.single.serverVersion),
        lastSyncedAt: Value(syncedAt),
      ),
    );
    return const SyncEntityResult(
      entityType: SyncEntityType.profile,
      status: SyncEntityStatus.succeeded,
      message: 'ok',
      pushedCount: 1,
    );
  }

  @override
  Future<SyncEntityResult> applyRemoteChanges({
    required List<SyncChange> changes,
    required int syncedAt,
    SyncPullMode pullMode = SyncPullMode.incremental,
  }) async => const SyncEntityResult(
    entityType: SyncEntityType.profile,
    status: SyncEntityStatus.succeeded,
    message: 'ok',
  );

  @override
  Future<List<SyncPushItem>> collectPending() async => const [];

  @override
  SyncChange decodeRemoteChange({
    required String recordId,
    required Map<String, Object?> payload,
    required int updatedAt,
    required int? deletedAt,
    required String originDeviceId,
    required int serverVersion,
  }) => SyncChange(
    entityType: entityType,
    operation: deletedAt == null ? SyncOperation.upsert : SyncOperation.delete,
    recordId: recordId,
    payload: deletedAt == null
        ? _ValuePayload(payload['value']! as String)
        : null,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
    originDeviceId: originDeviceId,
    serverVersion: serverVersion,
  );

  @override
  Map<String, Object?> encodePayload(SyncEntityPayload payload) => {
    'value': (payload as _ValuePayload).value,
  };
}
