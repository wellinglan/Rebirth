import 'package:rebirth/core/network/api_exception.dart';
import 'package:rebirth/core/config/server_endpoint_validator.dart';
import 'package:rebirth/core/utils/date_time_service.dart';
import 'package:rebirth/features/account/data/auth_session_store.dart';
import 'package:rebirth/features/account/domain/account_boundary.dart';
import 'package:rebirth/features/account/domain/auth_session.dart';
import 'package:rebirth/features/sync/data/dto/sync_dto.dart';
import 'package:rebirth/features/sync/data/sync_api_data_source.dart';
import 'package:rebirth/features/sync/domain/sync_entity_adapter.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_exception.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/domain/sync_cursor_store.dart';

typedef SyncEndpointProbe = Future<void> Function(String endpoint);
typedef SyncAccountScopeGuard =
    Future<void> Function({
      required String endpoint,
      required String cloudUserId,
    });

final class SyncCoordinator {
  SyncCoordinator({
    required this.endpoint,
    required this.sessionStore,
    required this.remoteDataSource,
    required this.cursorStore,
    required this.adapterRegistry,
    required this.endpointProbe,
    required this.dateTimeService,
    required this.accountScopeGuard,
    this.endpointValidator = const ServerEndpointValidator(),
  });

  final String endpoint;
  final AuthSessionStore sessionStore;
  final SyncRemoteDataSource remoteDataSource;
  final SyncCursorStore cursorStore;
  final SyncEntityAdapterRegistry adapterRegistry;
  final SyncEndpointProbe endpointProbe;
  final DateTimeService dateTimeService;
  final SyncAccountScopeGuard accountScopeGuard;
  final ServerEndpointValidator endpointValidator;

  _ActiveSyncRun? _activeRun;

  bool get isRunning => _activeRun != null;

  Future<SyncRunResult> run({
    required SyncRunDirection direction,
    Iterable<SyncEntityType>? entityTypes,
    SyncPullMode pullMode = SyncPullMode.incremental,
  }) {
    if (pullMode != SyncPullMode.incremental &&
        direction != SyncRunDirection.pull) {
      throw ArgumentError('Conflict resolution requires a pull-only run.');
    }
    final request = _SyncRunRequest(
      direction: direction,
      entityTypes: _normalizeEntityTypes(
        entityTypes ?? adapterRegistry.registeredTypes,
      ),
      pullMode: pullMode,
    );
    final activeRun = _activeRun;
    if (activeRun != null) {
      if (activeRun.request.matches(request)) return activeRun.future;
      return Future.value(_syncInProgressResult(request));
    }

    final future = _run(
      direction: request.direction,
      entityTypes: request.entityTypes,
      pullMode: request.pullMode,
    );
    _activeRun = _ActiveSyncRun(request: request, future: future);
    future.then<void>(
      (_) => _clearActiveRun(future),
      onError: (Object _, StackTrace _) => _clearActiveRun(future),
    );
    return future;
  }

  List<SyncEntityType> _normalizeEntityTypes(
    Iterable<SyncEntityType> entityTypes,
  ) {
    final normalized = entityTypes.toSet().toList(growable: false)
      ..sort((left, right) => left.index.compareTo(right.index));
    return List.unmodifiable(normalized);
  }

  void _clearActiveRun(Future<SyncRunResult> completedFuture) {
    if (identical(_activeRun?.future, completedFuture)) {
      _activeRun = null;
    }
  }

  SyncRunResult _syncInProgressResult(_SyncRunRequest request) {
    final timestamp = dateTimeService.currentSnapshot().utcMilliseconds;
    const message = '已有同步任务正在进行，请稍后重试。';
    return SyncRunResult(
      direction: request.direction,
      phases: const [SyncRunPhase.failed],
      entityResults: request.entityTypes
          .map(
            (entityType) => SyncEntityResult(
              entityType: entityType,
              status: SyncEntityStatus.failed,
              message: message,
            ),
          )
          .toList(growable: false),
      startedAt: timestamp,
      completedAt: timestamp,
      failure: const SyncFailure(
        reason: SyncFailureReason.syncInProgress,
        phase: SyncRunPhase.failed,
        message: message,
      ),
    );
  }

  Future<SyncRunResult> _run({
    required SyncRunDirection direction,
    required List<SyncEntityType> entityTypes,
    required SyncPullMode pullMode,
  }) async {
    final startedAt = dateTimeService.currentSnapshot().utcMilliseconds;
    final phases = <SyncRunPhase>[];
    final entityResults = <SyncEntityResult>[];
    SyncFailure? firstFailure;

    SyncRunResult finish() {
      final completedAt = dateTimeService.currentSnapshot().utcMilliseconds;
      phases.add(
        firstFailure == null ? SyncRunPhase.completed : SyncRunPhase.failed,
      );
      return SyncRunResult(
        direction: direction,
        phases: phases,
        entityResults: entityResults,
        startedAt: startedAt,
        completedAt: completedAt,
        failure: firstFailure,
      );
    }

    for (final entityType in entityTypes) {
      try {
        adapterRegistry.adapterFor(entityType);
      } on SyncUnsupportedEntityException {
        firstFailure = SyncFailure(
          reason: SyncFailureReason.unsupportedEntity,
          phase: SyncRunPhase.collectPending,
          message: '未注册 ${entityType.wireName} 同步适配器。',
          entityType: entityType,
        );
        entityResults.add(
          SyncEntityResult(
            entityType: entityType,
            status: SyncEntityStatus.failed,
            message: firstFailure.message,
          ),
        );
        return finish();
      }
    }

    phases.add(SyncRunPhase.endpointCheck);
    if (endpoint.trim().isEmpty) {
      firstFailure = const SyncFailure(
        reason: SyncFailureReason.endpointUnavailable,
        phase: SyncRunPhase.endpointCheck,
        message: '同步 Endpoint 未配置。',
      );
      return finish();
    }
    try {
      await endpointProbe(endpoint);
    } catch (_) {
      firstFailure = const SyncFailure(
        reason: SyncFailureReason.endpointUnavailable,
        phase: SyncRunPhase.endpointCheck,
        message: '当前 Endpoint 暂不可用。',
      );
      return finish();
    }

    phases.add(SyncRunPhase.sessionCheck);
    final session = await sessionStore.read();
    if (session == null || session.accessToken.trim().isEmpty) {
      firstFailure = const SyncFailure(
        reason: SyncFailureReason.authenticationRequired,
        phase: SyncRunPhase.sessionCheck,
        message: '请先完成开发登录。',
      );
      return finish();
    }
    if (session.user.id.trim().isEmpty) {
      firstFailure = const SyncFailure(
        reason: SyncFailureReason.cloudUserUnavailable,
        phase: SyncRunPhase.sessionCheck,
        message: '当前云端用户身份不可用。',
      );
      return finish();
    }
    if (!_sessionMatchesEndpoint(session)) {
      firstFailure = const SyncFailure(
        reason: SyncFailureReason.authenticationRequired,
        phase: SyncRunPhase.sessionCheck,
        message: 'Endpoint 已变化，请重新登录并注册设备。',
      );
      return finish();
    }

    phases.add(SyncRunPhase.accountScopeCheck);
    try {
      await accountScopeGuard(endpoint: endpoint, cloudUserId: session.user.id);
    } on AccountSyncReviewRequiredException catch (error) {
      firstFailure = SyncFailure(
        reason: SyncFailureReason.accountSyncReviewRequired,
        phase: SyncRunPhase.accountScopeCheck,
        message: error.message,
      );
      return finish();
    } on AccountScopeMismatchException catch (error) {
      firstFailure = SyncFailure(
        reason: SyncFailureReason.accountScopeMismatch,
        phase: SyncRunPhase.accountScopeCheck,
        message: error.message,
      );
      return finish();
    } catch (_) {
      firstFailure = const SyncFailure(
        reason: SyncFailureReason.accountScopeMismatch,
        phase: SyncRunPhase.accountScopeCheck,
        message: '无法验证当前账号的数据空间，已停止同步。',
      );
      return finish();
    }

    phases.add(SyncRunPhase.deviceCheck);
    final registration = session.deviceRegistration;
    if (registration == null || !registration.isRegistered) {
      firstFailure = const SyncFailure(
        reason: SyncFailureReason.deviceRegistrationRequired,
        phase: SyncRunPhase.deviceCheck,
        message: '请先注册当前设备。',
      );
      return finish();
    }

    for (final entityType in entityTypes) {
      final adapter = adapterRegistry.adapterFor(entityType);
      var progress = SyncEntityResult(
        entityType: entityType,
        status: SyncEntityStatus.noChanges,
        message: '没有需要同步的更新',
      );
      try {
        final result = await _runEntity(
          direction: direction,
          adapter: adapter,
          session: session,
          deviceId: registration.deviceId,
          phases: phases,
          pullMode: pullMode,
          onProgress: (result) => progress = result,
        );
        entityResults.add(result);
        if (!result.isSuccessful && firstFailure == null) {
          firstFailure = SyncFailure(
            reason: result.status == SyncEntityStatus.conflict
                ? SyncFailureReason.conflict
                : SyncFailureReason.unexpected,
            phase: result.status == SyncEntityStatus.conflict
                ? SyncRunPhase.apply
                : SyncRunPhase.failed,
            message: result.message,
            entityType: entityType,
          );
        }
      } on _SyncPhaseException catch (error) {
        firstFailure ??= SyncFailure(
          reason: error.reason,
          phase: error.phase,
          message: error.message,
          entityType: entityType,
        );
        entityResults.add(
          progress.merge(
            SyncEntityResult(
              entityType: entityType,
              status: SyncEntityStatus.failed,
              message: error.message,
            ),
          ),
        );
      } catch (error) {
        final phase = phases.isEmpty ? SyncRunPhase.failed : phases.last;
        firstFailure ??= SyncFailure(
          reason: _reasonFor(error, phase),
          phase: phase,
          message: _messageFor(error, phase),
          entityType: entityType,
        );
        entityResults.add(
          progress.merge(
            SyncEntityResult(
              entityType: entityType,
              status: SyncEntityStatus.failed,
              message: firstFailure.message,
            ),
          ),
        );
      }
    }

    return finish();
  }

  Future<SyncEntityResult> _runEntity({
    required SyncRunDirection direction,
    required SyncEntityAdapter adapter,
    required AuthSession session,
    required String deviceId,
    required List<SyncRunPhase> phases,
    required SyncPullMode pullMode,
    required void Function(SyncEntityResult result) onProgress,
  }) async {
    var aggregate = SyncEntityResult(
      entityType: adapter.entityType,
      status: SyncEntityStatus.noChanges,
      message: '没有需要同步的更新',
    );

    if (direction != SyncRunDirection.pull) {
      phases.add(SyncRunPhase.collectPending);
      final pending = await adapter.collectPending();
      if (pending.isNotEmpty) {
        for (final item in pending) {
          _validatePushItem(item, adapter.entityType);
        }
        phases.add(SyncRunPhase.push);
        final response = await remoteDataSource.push(
          SyncPushRequestDto(
            deviceId: deviceId,
            items: pending
                .map(
                  (item) => SyncPushItemDto(
                    tableName: item.entityType.wireName,
                    recordId: item.recordId,
                    payload: item.payload == null
                        ? const {}
                        : adapter.encodePayload(item.payload!),
                    updatedAt: item.updatedAt,
                    deletedAt: item.deletedAt,
                    originDeviceId: item.originDeviceId,
                    clientVersion: item.clientVersion,
                  ),
                )
                .toList(growable: false),
          ),
          accessToken: session.accessToken,
        );
        phases.add(SyncRunPhase.acknowledgePush);
        final acknowledged = await adapter.acknowledgePush(
          submitted: pending,
          accepted: response.accepted
              .map(
                (item) => SyncAcknowledgement(
                  entityType: SyncEntityType.parse(item.tableName),
                  recordId: item.recordId,
                  serverVersion: item.serverVersion,
                ),
              )
              .toList(growable: false),
          conflicts: response.conflicts,
          syncedAt: dateTimeService.currentSnapshot().utcMilliseconds,
        );
        aggregate = aggregate.merge(acknowledged);
        onProgress(aggregate);
        if (!acknowledged.isSuccessful) return aggregate;
      }
    }

    if (direction != SyncRunDirection.push) {
      phases.add(SyncRunPhase.cursorRead);
      final cursorValue = await cursorStore.read(
        endpoint: endpoint,
        cloudUserId: session.user.id,
        scope: adapter.entityType.wireName,
      );
      if (cursorValue < 0) {
        throw const InvalidSyncCursorException();
      }
      final cursor = SyncCursor(
        endpoint: endpoint,
        cloudUserId: session.user.id,
        scope: adapter.entityType,
        serverVersion: cursorValue,
      );

      phases.add(SyncRunPhase.pull);
      final response = await remoteDataSource.pull(
        SyncPullRequestDto(
          deviceId: deviceId,
          sinceServerVersion: pullMode == SyncPullMode.incremental
              ? cursor.serverVersion
              : 0,
          tables: [adapter.entityType.wireName],
        ),
        accessToken: session.accessToken,
      );
      if (pullMode == SyncPullMode.incremental &&
          response.serverVersion < cursor.serverVersion) {
        throw const _SyncPhaseException(
          reason: SyncFailureReason.pullFailed,
          phase: SyncRunPhase.pull,
          message: '后端返回了倒退的同步游标。',
        );
      }
      final changes = <SyncChange>[];
      for (final item in response.items) {
        final remoteType = SyncEntityType.parse(item.tableName);
        if (remoteType != adapter.entityType) {
          throw _SyncPhaseException(
            reason: SyncFailureReason.payloadInvalid,
            phase: SyncRunPhase.pull,
            message: '后端返回了未请求的 ${item.tableName} 数据。',
          );
        }
        changes.add(
          adapter.decodeRemoteChange(
            recordId: item.recordId,
            payload: item.payload,
            updatedAt: item.updatedAt,
            deletedAt: item.deletedAt,
            originDeviceId: item.originDeviceId,
            serverVersion: item.serverVersion,
          ),
        );
      }
      final page = SyncPullPage(
        entityType: adapter.entityType,
        serverVersion: response.serverVersion,
        changes: changes,
      );

      phases.add(SyncRunPhase.apply);
      final applied = await adapter.applyRemoteChanges(
        changes: page.changes,
        syncedAt: dateTimeService.currentSnapshot().utcMilliseconds,
        pullMode: pullMode,
      );
      aggregate = aggregate.merge(applied);
      onProgress(aggregate);
      if (!applied.isSuccessful) return aggregate;

      phases.add(SyncRunPhase.cursorAdvance);
      await cursorStore.write(
        endpoint: cursor.endpoint,
        cloudUserId: cursor.cloudUserId,
        scope: cursor.scope.wireName,
        serverVersion: page.serverVersion < cursor.serverVersion
            ? cursor.serverVersion
            : page.serverVersion,
      );
    }

    return aggregate;
  }

  bool _sessionMatchesEndpoint(AuthSession session) {
    final sessionEndpoint = session.serverBaseUrl.trim();
    if (sessionEndpoint.isEmpty) return false;
    try {
      return endpointValidator.normalize(sessionEndpoint) ==
          endpointValidator.normalize(endpoint);
    } on FormatException {
      return false;
    }
  }

  void _validatePushItem(SyncPushItem item, SyncEntityType expectedEntityType) {
    if (item.entityType != expectedEntityType) {
      throw SyncUnsupportedEntityException(item.entityType.wireName);
    }
    final isUpsert = item.operation == SyncOperation.upsert;
    if (isUpsert != (item.deletedAt == null) ||
        (isUpsert && item.payload == null) ||
        item.updatedAt < 0 ||
        item.clientVersion < 0) {
      throw const SyncException('本地同步记录的 operation 或版本无效。');
    }
  }

  static SyncFailureReason _reasonFor(Object error, SyncRunPhase phase) {
    if (error is SyncUnsupportedEntityException) {
      return SyncFailureReason.unsupportedEntity;
    }
    if (error is SyncAuthenticationRequiredException) {
      return SyncFailureReason.authenticationRequired;
    }
    if (error is SyncDeviceRegistrationRequiredException) {
      return SyncFailureReason.deviceRegistrationRequired;
    }
    if (error is AccountScopeMismatchException) {
      return SyncFailureReason.accountScopeMismatch;
    }
    if (error is AccountSyncReviewRequiredException) {
      return SyncFailureReason.accountSyncReviewRequired;
    }
    if (error is ApiException) {
      return phase == SyncRunPhase.push
          ? SyncFailureReason.pushFailed
          : SyncFailureReason.pullFailed;
    }
    if (phase == SyncRunPhase.cursorRead ||
        phase == SyncRunPhase.cursorAdvance) {
      return SyncFailureReason.cursorFailed;
    }
    if (error is SyncException) return SyncFailureReason.payloadInvalid;
    if (phase == SyncRunPhase.apply || phase == SyncRunPhase.acknowledgePush) {
      return SyncFailureReason.applyFailed;
    }
    return SyncFailureReason.unexpected;
  }

  static String _messageFor(Object error, SyncRunPhase phase) {
    if (error is SyncException) return error.message;
    if (error is SyncUnsupportedEntityException) {
      return '未注册 ${error.entityType} 同步适配器。';
    }
    if (error is ApiException) {
      return phase == SyncRunPhase.push
          ? '数据上传失败，本地记录未受影响。'
          : '数据拉取失败，本地记录未受影响。';
    }
    if (phase == SyncRunPhase.cursorRead) {
      return '本地同步游标读取失败，已停止拉取。';
    }
    if (phase == SyncRunPhase.cursorAdvance) {
      return '同步已应用，但游标保存失败；下次将安全重放。';
    }
    return '同步失败，本地记录未受影响。';
  }
}

final class _SyncRunRequest {
  const _SyncRunRequest({
    required this.direction,
    required this.entityTypes,
    required this.pullMode,
  });

  final SyncRunDirection direction;
  final List<SyncEntityType> entityTypes;
  final SyncPullMode pullMode;

  bool matches(_SyncRunRequest other) {
    if (direction != other.direction ||
        pullMode != other.pullMode ||
        entityTypes.length != other.entityTypes.length) {
      return false;
    }
    for (var index = 0; index < entityTypes.length; index += 1) {
      if (entityTypes[index] != other.entityTypes[index]) return false;
    }
    return true;
  }
}

final class _ActiveSyncRun {
  const _ActiveSyncRun({required this.request, required this.future});

  final _SyncRunRequest request;
  final Future<SyncRunResult> future;
}

final class _SyncPhaseException implements Exception {
  const _SyncPhaseException({
    required this.reason,
    required this.phase,
    required this.message,
  });

  final SyncFailureReason reason;
  final SyncRunPhase phase;
  final String message;
}
