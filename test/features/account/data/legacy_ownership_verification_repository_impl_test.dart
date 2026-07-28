import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/account/data/account_boundary_repository_impl.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/account/data/legacy_ownership_verification_api_data_source.dart';
import 'package:rebirth/features/account/data/legacy_ownership_verification_repository_impl.dart';
import 'package:rebirth/features/account/domain/account_boundary.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/account/domain/auth_user.dart';
import 'package:rebirth/features/account/domain/legacy_ownership_verification.dart';

void main() {
  late AppDatabase database;
  late _MemorySessionStore sessionStore;
  late _FakeRemoteDataSource remote;
  late LegacyOwnershipVerificationRepositoryImpl repository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    sessionStore = _MemorySessionStore(_session);
    remote = _FakeRemoteDataSource();
    repository = LegacyOwnershipVerificationRepositoryImpl(
      database: database,
      sessionStore: sessionStore,
      remoteDataSource: remote,
      dateTimeService: DateTimeService(
        now: () => DateTime.utc(2031, 2, 3, 4, 5, 6),
      ),
    );
    await _seedClaimedLegacySpace(database);
  });

  tearDown(() => database.close());

  test('verified response atomically unlocks the legacy binding', () async {
    remote.result = _result(LegacyOwnershipVerificationOutcome.verified);

    final result = await repository.verifyCurrentDataSpace();

    expect(result.isVerified, isTrue);
    expect(remote.calls, 1);
    expect(remote.lastToken, 'token-account-a');
    expect(remote.lastEvidence, hasLength(1));
    expect(remote.lastEvidence.single.tableName, 'goals');
    for (final evidence in remote.lastEvidence) {
      expect(evidence.metadataFingerprint, matches(RegExp(r'^[0-9a-f]{64}$')));
    }
    final binding = await database
        .select(database.cloudAccountBindings)
        .getSingle();
    expect(binding.syncEligibilityStatus, 'ready');
    expect(binding.verificationStatus, 'verified');
    expect(binding.verificationTime, 1927857906000);
    expect(binding.verificationMethod, 'server_sync_metadata_v1');
    expect(binding.verificationReason, 'all_evidence_matches_current_user');
    expect(
      await AccountBoundaryRepositoryImpl(
        database: database,
        dateTimeService: const DateTimeService(),
        platform: 'windows',
      ).requireActiveScope(endpoint: _endpoint, cloudUserId: 'account-a'),
      binding.localUserId,
    );
  });

  test('profile metadata is used only when no synced Goal exists', () async {
    await database.delete(database.goals).go();
    remote.result = _result(LegacyOwnershipVerificationOutcome.verified);

    await repository.verifyCurrentDataSpace();

    expect(remote.lastEvidence, hasLength(1));
    expect(remote.lastEvidence.single.tableName, 'user_profiles');
  });

  test('unknown response records the attempt and remains blocked', () async {
    remote.result = _result(LegacyOwnershipVerificationOutcome.unknown);

    await repository.verifyCurrentDataSpace();

    final binding = await database
        .select(database.cloudAccountBindings)
        .getSingle();
    expect(binding.syncEligibilityStatus, 'legacy_review_required');
    expect(binding.verificationStatus, 'not_verified');
    expect(binding.verificationReason, 'remote_record_missing');
    await expectLater(
      AccountBoundaryRepositoryImpl(
        database: database,
        dateTimeService: const DateTimeService(),
        platform: 'windows',
      ).requireActiveScope(endpoint: _endpoint, cloudUserId: 'account-a'),
      throwsA(isA<AccountSyncReviewRequiredException>()),
    );
  });

  test('rejected response records failure and remains blocked', () async {
    remote.result = _result(LegacyOwnershipVerificationOutcome.rejected);

    await repository.verifyCurrentDataSpace();

    final binding = await database
        .select(database.cloudAccountBindings)
        .getSingle();
    expect(binding.syncEligibilityStatus, 'legacy_review_required');
    expect(binding.verificationStatus, 'failed');
    expect(binding.verificationReason, 'metadata_mismatch_or_other_owner');
  });

  test(
    'network failure writes nothing and a later retry can succeed',
    () async {
      final before = await database
          .select(database.cloudAccountBindings)
          .getSingle();
      remote.error = const ApiException(
        message: 'offline',
        isNetworkError: true,
      );

      await expectLater(
        repository.verifyCurrentDataSpace(),
        throwsA(isA<ApiException>()),
      );

      final afterFailure = await database
          .select(database.cloudAccountBindings)
          .getSingle();
      expect(afterFailure, before);
      remote
        ..error = null
        ..result = _result(LegacyOwnershipVerificationOutcome.verified);
      final retried = await repository.verifyCurrentDataSpace();
      expect(retried.isVerified, isTrue);
      expect(remote.calls, 2);
    },
  );

  test('session change before commit rejects the server result', () async {
    remote
      ..result = _result(LegacyOwnershipVerificationOutcome.verified)
      ..afterCall = () => sessionStore.session = _sessionFor('account-b');

    await expectLater(
      repository.verifyCurrentDataSpace(),
      throwsA(isA<AccountSessionRejectedException>()),
    );

    final binding = await database
        .select(database.cloudAccountBindings)
        .getSingle();
    expect(binding.syncEligibilityStatus, 'legacy_review_required');
    expect(binding.verificationStatus, 'not_verified');
  });
}

Future<void> _seedClaimedLegacySpace(AppDatabase database) async {
  final bootstrap = await database.bootstrapDao.bootstrap(
    createUnboundProfile: true,
  );
  await (database.update(
    database.userProfiles,
  )..where((row) => row.id.equals(bootstrap.activeUserId))).write(
    UserProfilesCompanion(
      syncStatus: const Value('synced'),
      serverVersion: const Value(11),
      lastSyncedAt: const Value(900),
      updatedAt: const Value(800),
      originDeviceId: Value(bootstrap.localInstallationId),
    ),
  );
  await database
      .into(database.goals)
      .insert(
        GoalsCompanion.insert(
          id: const Value('10000000-0000-4000-8000-000000000001'),
          userId: bootstrap.activeUserId,
          title: 'private title never leaves the repository',
          goalLevel: 'month',
          syncStatus: const Value('synced'),
          serverVersion: const Value(12),
          lastSyncedAt: const Value(900),
          updatedAt: const Value(850),
          originDeviceId: Value(bootstrap.localInstallationId),
        ),
      );
  final boundary = AccountBoundaryRepositoryImpl(
    database: database,
    dateTimeService: DateTimeService(
      now: () => DateTime.utc(2030, 1, 2, 3, 4, 5),
    ),
    platform: 'windows',
  );
  final pending = await boundary.resolveAndActivate(_session);
  await boundary.claimLegacyDataSpace(
    session: _session,
    expectedScope: pending.accountScope!,
    localUserId: bootstrap.activeUserId,
  );
}

LegacyOwnershipVerificationResult _result(
  LegacyOwnershipVerificationOutcome outcome,
) {
  return LegacyOwnershipVerificationResult(
    outcome: outcome,
    verifiedCount: outcome == LegacyOwnershipVerificationOutcome.verified
        ? 2
        : 0,
    rejectedCount: outcome == LegacyOwnershipVerificationOutcome.rejected
        ? 1
        : 0,
    unknownCount: outcome == LegacyOwnershipVerificationOutcome.unknown ? 1 : 0,
    reason: switch (outcome) {
      LegacyOwnershipVerificationOutcome.verified =>
        LegacyOwnershipVerificationReason.allEvidenceMatchesCurrentUser,
      LegacyOwnershipVerificationOutcome.unknown =>
        LegacyOwnershipVerificationReason.remoteRecordMissing,
      LegacyOwnershipVerificationOutcome.rejected =>
        LegacyOwnershipVerificationReason.metadataMismatchOrOtherOwner,
    },
  );
}

const _endpoint = 'https://alpha.example.test';
const _session = AuthSession(
  accessToken: 'token-account-a',
  refreshToken: 'refresh-account-a',
  user: AuthUser(id: 'account-a', displayName: 'Account A'),
  serverBaseUrl: _endpoint,
);

AuthSession _sessionFor(String userId) => AuthSession(
  accessToken: 'token-$userId',
  refreshToken: 'refresh-$userId',
  user: AuthUser(id: userId, displayName: userId),
  serverBaseUrl: _endpoint,
);

final class _MemorySessionStore implements AuthSessionStore {
  _MemorySessionStore(this.session);

  AuthSession? session;

  @override
  Future<void> clear() async => session = null;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> save(AuthSession value) async => session = value;
}

final class _FakeRemoteDataSource
    implements LegacyOwnershipVerificationRemoteDataSource {
  LegacyOwnershipVerificationResult? result;
  Object? error;
  void Function()? afterCall;
  int calls = 0;
  String? lastToken;
  List<LegacyOwnershipEvidence> lastEvidence = const [];

  @override
  Future<LegacyOwnershipVerificationResult> verify({
    required List<LegacyOwnershipEvidence> evidence,
    required String accessToken,
  }) async {
    calls += 1;
    lastToken = accessToken;
    lastEvidence = List.unmodifiable(evidence);
    afterCall?.call();
    if (error case final current?) throw current;
    return result!;
  }
}
