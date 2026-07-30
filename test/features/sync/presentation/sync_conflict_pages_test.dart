import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rebirth/core/router/route_names.dart';
import 'package:rebirth/features/health/domain/health_sync_payload.dart';
import 'package:rebirth/features/journal/domain/journal_entry.dart';
import 'package:rebirth/features/journal/domain/journal_sync_payload.dart';
import 'package:rebirth/features/plan/domain/plan_goal.dart';
import 'package:rebirth/features/plan/domain/plan_sync_payload.dart';
import 'package:rebirth/features/sync/data/sync_conflict_providers.dart';
import 'package:rebirth/features/sync/domain/sync_conflict_record.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/presentation/plan_sync_controller.dart';
import 'package:rebirth/features/sync/presentation/plan_sync_view_state.dart';
import 'package:rebirth/features/sync/presentation/sync_conflict_detail_page.dart';
import 'package:rebirth/features/sync/presentation/sync_conflict_list_page.dart';
import 'package:rebirth/features/sync/presentation/sync_conflict_resolution_handlers.dart';
import 'package:rebirth/features/today/domain/today_entry.dart';
import 'package:rebirth/features/today/domain/today_sync_payload.dart';

void main() {
  test('module filters group both Journal entity types', () {
    expect(
      SyncConflictModuleFilter.journal.includes(
        SyncEntityType.journalPromptConfiguration,
      ),
      isTrue,
    );
    expect(
      SyncConflictModuleFilter.journal.includes(SyncEntityType.journal),
      isTrue,
    );
    expect(
      SyncConflictModuleFilter.journal.includes(SyncEntityType.health),
      isFalse,
    );
    expect(
      SyncConflictModuleFilter.fromStableId('module.profile'),
      SyncConflictModuleFilter.profile,
    );
    expect(
      SyncConflictModuleFilter.fromStableId('unknown'),
      SyncConflictModuleFilter.all,
    );
  });

  testWidgets('conflict list renders loading, empty, error, and Plan title', (
    tester,
  ) async {
    await _pumpList(
      tester,
      future: Completer<List<SyncConflictRecord>>().future,
    );
    expect(
      find.byKey(const ValueKey('syncConflictListLoading')),
      findsOneWidget,
    );

    await _pumpList(tester, items: const []);
    expect(find.byKey(const ValueKey('syncConflictListEmpty')), findsOneWidget);
    expect(find.text('无待处理问题'), findsOneWidget);

    await _pumpList(tester, error: StateError('storage'));
    expect(find.byKey(const ValueKey('syncConflictListError')), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await _pumpList(tester, items: [_record()]);
    expect(find.byKey(const ValueKey('syncConflictList')), findsOneWidget);
    expect(find.text('Local title'), findsOneWidget);
    expect(find.textContaining('Plan · 双端修改'), findsOneWidget);
    expect(find.textContaining(_conflictId), findsNothing);
  });

  testWidgets('awaiting conflict only offers hydration retry', (tester) async {
    final controller = _RecordingPlanSyncController();
    await _pumpDetails(
      tester,
      details: _details(
        record: _record(
          status: SyncConflictResolutionStatus.awaitingRemoteSnapshot,
          operation: SyncConflictOperation.unknownPendingPull,
          remotePayload: null,
        ),
      ),
      controller: controller,
    );

    expect(find.text('需要重新同步以获取服务器当前版本。'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('retryConflictHydrationButton')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('adoptRemoteButton')), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('retryConflictHydrationButton')),
    );
    await tester.pumpAndSettle();
    expect(controller.calls, ['hydrate']);
  });

  testWidgets(
    'upsert details compare typed summaries and changed local state',
    (tester) async {
      await _pumpDetails(tester, details: _details(localChanged: true));

      expect(find.text('本地版本'), findsOneWidget);
      expect(find.text('云端版本'), findsOneWidget);
      expect(find.text('标题：Current local title'), findsOneWidget);
      expect(find.text('标题：Remote title'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('localSnapshotChangedNotice')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('adoptRemoteButton')), findsOneWidget);
      expect(find.byKey(const ValueKey('keepLocalButton')), findsOneWidget);
      expect(find.textContaining(_recordId), findsNothing);
      expect(find.textContaining('{'), findsNothing);
    },
  );

  testWidgets('tombstone details are explicit without a fabricated payload', (
    tester,
  ) async {
    await _pumpDetails(
      tester,
      details: _details(
        record: _record(
          operation: SyncConflictOperation.delete,
          remotePayload: null,
          remoteDeletedAt: 900,
        ),
      ),
    );

    expect(find.text('标题：已删除的 Plan 目标'), findsOneWidget);
    expect(find.text('删除：是'), findsOneWidget);
    expect(find.text('云端版本：6'), findsOneWidget);
  });

  testWidgets('Today conflict is readable and offers explicit recovery', (
    tester,
  ) async {
    await _pumpDetails(tester, details: _todayDetails());

    expect(find.text('2026-07-28 Today'), findsOneWidget);
    expect(find.text('日期：2026-07-28'), findsNWidgets(2));
    expect(find.text('心情：4'), findsOneWidget);
    expect(find.text('心情：5'), findsOneWidget);
    expect(find.byKey(const ValueKey('adoptRemoteButton')), findsOneWidget);
    expect(find.byKey(const ValueKey('keepLocalButton')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('unsupportedConflictProtectedNotice')),
      findsNothing,
    );
  });

  testWidgets('Today actions dispatch through the Today handler', (
    tester,
  ) async {
    final handler = _RecordingConflictHandler(SyncEntityType.today);
    await _pumpDetails(
      tester,
      details: _todayDetails(),
      handlerRegistry: SyncConflictResolutionHandlerRegistry([handler]),
    );

    await tester.tap(find.byKey(const ValueKey('adoptRemoteButton')));
    await tester.pumpAndSettle();
    expect(find.textContaining('同日 Health 不会删除'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirmAdoptRemoteButton')));
    await tester.pumpAndSettle();

    expect(handler.calls, ['adopt']);
  });

  testWidgets('Journal conflict uses the generic comparison and handler UI', (
    tester,
  ) async {
    final handler = _RecordingConflictHandler(SyncEntityType.journal);
    await _pumpDetails(
      tester,
      details: _journalDetails(),
      handlerRegistry: SyncConflictResolutionHandlerRegistry([handler]),
    );

    expect(find.text('2026-07-28 Journal'), findsOneWidget);
    expect(find.text('日期：2026-07-28'), findsNWidgets(2));
    expect(find.text('学习：Local Journal'), findsOneWidget);
    expect(find.text('学习：Remote Journal'), findsOneWidget);
    expect(find.byKey(const ValueKey('adoptRemoteButton')), findsOneWidget);
    expect(find.byKey(const ValueKey('keepLocalButton')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('keepLocalButton')));
    await tester.pumpAndSettle();
    expect(find.textContaining('本地 Journal 将覆盖服务器'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirmKeepLocalButton')));
    await tester.pumpAndSettle();
    expect(handler.calls, ['keep']);
  });

  testWidgets(
    'Health conflict hides sensitive values and uses generic actions',
    (tester) async {
      final handler = _RecordingConflictHandler(SyncEntityType.health);
      await _pumpDetails(
        tester,
        details: _healthDetails(),
        handlerRegistry: SyncConflictResolutionHandlerRegistry([handler]),
      );

      expect(find.text('2026-07-28 Health'), findsOneWidget);
      expect(find.text('日期：2026-07-28'), findsNWidgets(2));
      expect(find.text('记录类型：手动记录'), findsNWidgets(2));
      expect(find.text('内容：健康详情已隐藏'), findsNWidgets(2));
      expect(find.textContaining('Private local note'), findsNothing);
      expect(find.textContaining('Private remote note'), findsNothing);
      expect(find.textContaining('450'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('adoptRemoteButton')));
      await tester.pumpAndSettle();
      expect(find.textContaining('本地 Health 记录将被服务器当前版本替换'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirmAdoptRemoteButton')));
      await tester.pumpAndSettle();
      expect(handler.calls, ['adopt']);
    },
  );

  testWidgets('adopt confirmation can cancel without invoking controller', (
    tester,
  ) async {
    final controller = _RecordingPlanSyncController();
    await _pumpDetails(tester, details: _details(), controller: controller);

    await tester.tap(find.byKey(const ValueKey('adoptRemoteButton')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('confirmAdoptRemoteDialog')),
      findsOneWidget,
    );
    expect(find.textContaining('本地冲突修改尚未上传'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(controller.calls, isEmpty);
  });

  testWidgets('adopt and keep confirmations invoke explicit actions', (
    tester,
  ) async {
    final controller = _RecordingPlanSyncController();
    await _pumpDetails(tester, details: _details(), controller: controller);

    await tester.tap(find.byKey(const ValueKey('adoptRemoteButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmAdoptRemoteButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('keepLocalButton')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('confirmKeepLocalDialog')),
      findsOneWidget,
    );
    expect(find.textContaining('当前本地目标将覆盖服务器版本'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirmKeepLocalButton')));
    await tester.pumpAndSettle();

    expect(controller.calls, ['adopt', 'keep']);
  });

  testWidgets('requested and resolved states expose only valid controls', (
    tester,
  ) async {
    final controller = _RecordingPlanSyncController();
    await _pumpDetails(
      tester,
      details: _details(
        record: _record(
          status: SyncConflictResolutionStatus.keepLocalRequested,
        ),
      ),
      controller: controller,
    );
    expect(
      find.byKey(const ValueKey('retryConflictResolutionButton')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('adoptRemoteButton')), findsNothing);
    expect(find.byKey(const ValueKey('keepLocalButton')), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('retryConflictResolutionButton')),
    );
    await tester.pumpAndSettle();
    expect(controller.calls, ['retry']);

    await _pumpDetails(
      tester,
      details: _details(
        record: _record(
          status: SyncConflictResolutionStatus.resolvedKeepLocal,
          resolvedAt: 1_000,
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('resolvedConflictNotice')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('adoptRemoteButton')), findsNothing);
  });

  testWidgets('detail not-found and operation failure are controlled', (
    tester,
  ) async {
    await _pumpDetails(tester, error: const SyncConflictNotFoundException());
    expect(
      find.byKey(const ValueKey('syncConflictDetailNotFound')),
      findsOneWidget,
    );

    final controller = _RecordingPlanSyncController(shouldFail: true);
    await _pumpDetails(tester, details: _details(), controller: controller);
    await tester.tap(find.byKey(const ValueKey('keepLocalButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmKeepLocalButton')));
    await tester.pumpAndSettle();
    expect(find.text('操作未完成，本地 Plan 内容已保留'), findsOneWidget);
    expect(find.text('标题：Local title'), findsOneWidget);
  });

  testWidgets('non-throwing pull failure is not reported as completed', (
    tester,
  ) async {
    final handler = _RecordingConflictHandler(
      SyncEntityType.today,
      result: _failedHandlerResult(SyncEntityType.today),
    );
    await _pumpDetails(
      tester,
      details: _awaitingTodayDetails(),
      handlerRegistry: SyncConflictResolutionHandlerRegistry([handler]),
    );

    await tester.tap(
      find.byKey(const ValueKey('retryConflictHydrationButton')),
    );
    await tester.pumpAndSettle();

    expect(find.text('操作未完成，本地 Today 内容已保留'), findsOneWidget);
    expect(find.text('冲突操作已完成'), findsNothing);
  });

  for (final width in [320.0, 360.0, 412.0, 720.0, 840.0, 1200.0]) {
    testWidgets('conflict details have no overflow at width $width', (
      tester,
    ) async {
      await _pumpDetails(
        tester,
        details: _details(localChanged: true),
        size: Size(width, 900),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('conflict details support 2.0 text scale without overflow', (
    tester,
  ) async {
    await _pumpDetails(
      tester,
      details: _details(localChanged: true),
      size: const Size(320, 1000),
      textScaler: const TextScaler.linear(2),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('list route opens the matching conflict detail route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: RoutePaths.syncConflicts,
      routes: [
        GoRoute(
          path: RoutePaths.syncConflicts,
          builder: (_, _) => const SyncConflictListPage(),
          routes: [
            GoRoute(
              path: ':conflictId',
              builder: (_, state) => SyncConflictDetailPage(
                conflictId: state.pathParameters['conflictId']!,
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeSyncConflictListProvider.overrideWith(
            (ref) async => [_record()],
          ),
          syncConflictDetailsProvider.overrideWith(
            (ref, id) async => _details(),
          ),
          planSyncControllerProvider.overrideWith(
            _RecordingPlanSyncController.new,
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('syncConflict-$_conflictId')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('syncConflictDetailPage')),
      findsOneWidget,
    );
  });

  test(
    'sync presentation does not import Drift or database implementations',
    () {
      final directory = Directory('lib/features/sync/presentation');
      for (final file
          in directory.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        expect(source, isNot(contains('package:drift')));
        expect(source, isNot(contains('app_database')));
        expect(source, isNot(contains('RepositoryImpl')));
      }
    },
  );
}

Future<void> _pumpList(
  WidgetTester tester, {
  List<SyncConflictRecord>? items,
  Object? error,
  Future<List<SyncConflictRecord>>? future,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        activeSyncConflictListProvider.overrideWith((ref) async {
          if (error != null) throw error;
          if (future != null) return future;
          return items ?? const [];
        }),
      ],
      child: const MaterialApp(home: SyncConflictListPage()),
    ),
  );
  await tester.pump();
  if (future == null) await tester.pumpAndSettle();
}

Future<void> _pumpDetails(
  WidgetTester tester, {
  SyncConflictDetails? details,
  Object? error,
  _RecordingPlanSyncController? controller,
  Size size = const Size(900, 900),
  TextScaler textScaler = TextScaler.noScaling,
  SyncConflictResolutionHandlerRegistry? handlerRegistry,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final notifier = controller ?? _RecordingPlanSyncController();
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        syncConflictDetailsProvider.overrideWith((ref, id) async {
          if (error != null) throw error;
          return details ?? _details();
        }),
        planSyncControllerProvider.overrideWith(() => notifier),
        if (handlerRegistry != null)
          syncConflictResolutionHandlerRegistryProvider.overrideWithValue(
            handlerRegistry,
          ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: const SyncConflictDetailPage(conflictId: _conflictId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _RecordingConflictHandler implements SyncConflictResolutionHandler {
  _RecordingConflictHandler(this.entityType, {this._result});

  @override
  final SyncEntityType entityType;

  final List<String> calls = [];
  final SyncRunResult? _result;

  @override
  bool get isBusy => false;

  @override
  String? get resolvingConflictId => null;

  @override
  Future<SyncRunResult> adoptRemote(String conflictId) async {
    calls.add('adopt');
    return _result ?? _handlerResult(entityType);
  }

  @override
  Future<SyncRunResult> keepLocal(String conflictId) async {
    calls.add('keep');
    return _result ?? _handlerResult(entityType);
  }

  @override
  Future<SyncRunResult> retryHydration(String conflictId) async {
    calls.add('hydrate');
    return _result ?? _handlerResult(entityType);
  }

  @override
  Future<SyncRunResult> retryRequestedResolution(String conflictId) async {
    calls.add('retry');
    return _result ?? _handlerResult(entityType);
  }
}

SyncRunResult _handlerResult(SyncEntityType entityType) {
  return SyncRunResult(
    direction: SyncRunDirection.pull,
    phases: const [SyncRunPhase.completed],
    entityResults: [
      SyncEntityResult(
        entityType: entityType,
        status: SyncEntityStatus.succeeded,
        message: 'ok',
      ),
    ],
    startedAt: 1,
    completedAt: 2,
  );
}

SyncRunResult _failedHandlerResult(SyncEntityType entityType) {
  return SyncRunResult(
    direction: SyncRunDirection.pull,
    phases: const [SyncRunPhase.failed],
    entityResults: [
      SyncEntityResult(
        entityType: entityType,
        status: SyncEntityStatus.failed,
        message: '后端返回了倒退的同步游标。',
      ),
    ],
    startedAt: 1,
    completedAt: 2,
    failure: SyncFailure(
      reason: SyncFailureReason.pullFailed,
      phase: SyncRunPhase.pull,
      message: '后端返回了倒退的同步游标。',
      entityType: entityType,
    ),
  );
}

const _conflictId = '00000000-0000-4000-8000-000000000041';
const _recordId = '00000000-0000-4000-8000-000000000042';
const _scope = SyncConflictScope(
  localUserId: '00000000-0000-4000-8000-000000000043',
  endpointKey: 'http://server-a:8000',
  cloudUserId: 'cloud-a',
);

SyncConflictDetails _details({
  SyncConflictRecord? record,
  bool localChanged = false,
}) {
  return SyncConflictDetails(
    record: record ?? _record(),
    currentLocalSnapshot: localChanged
        ? _snapshot(title: 'Current local title', updatedAt: 800, version: 5)
        : null,
    localSnapshotChanged: localChanged,
  );
}

SyncConflictDetails _todayDetails() {
  return SyncConflictDetails(
    record: SyncConflictRecord(
      id: _conflictId,
      scope: _scope,
      entityType: SyncEntityType.today,
      recordId: _recordId,
      localSnapshot: SyncConflictSnapshot(
        payload: _todayPayload(mood: 4, note: 'Local'),
        updatedAt: 700,
        deletedAt: null,
        serverVersion: 5,
        originDeviceId: null,
      ),
      remoteSnapshot: SyncConflictSnapshot(
        payload: _todayPayload(mood: 5, note: 'Cloud'),
        updatedAt: 800,
        deletedAt: null,
        serverVersion: 6,
        originDeviceId: null,
      ),
      remoteOperation: SyncConflictOperation.upsert,
      detectedAt: 900,
      lastSeenAt: 900,
      resolutionStatus: SyncConflictResolutionStatus.unresolved,
      resolvedAt: null,
    ),
    currentLocalSnapshot: null,
    localSnapshotChanged: false,
  );
}

SyncConflictDetails _awaitingTodayDetails() {
  return SyncConflictDetails(
    record: SyncConflictRecord(
      id: _conflictId,
      scope: _scope,
      entityType: SyncEntityType.today,
      recordId: _recordId,
      localSnapshot: SyncConflictSnapshot(
        payload: _todayPayload(mood: 4, note: 'Local'),
        updatedAt: 700,
        deletedAt: null,
        serverVersion: 5,
        originDeviceId: null,
      ),
      remoteSnapshot: const SyncConflictSnapshot(
        payload: null,
        updatedAt: null,
        deletedAt: null,
        serverVersion: 6,
        originDeviceId: null,
      ),
      remoteOperation: SyncConflictOperation.unknownPendingPull,
      detectedAt: 900,
      lastSeenAt: 900,
      resolutionStatus: SyncConflictResolutionStatus.awaitingRemoteSnapshot,
      resolvedAt: null,
    ),
    currentLocalSnapshot: null,
    localSnapshotChanged: false,
  );
}

SyncConflictDetails _journalDetails() {
  return SyncConflictDetails(
    record: SyncConflictRecord(
      id: _conflictId,
      scope: _scope,
      entityType: SyncEntityType.journal,
      recordId: _recordId,
      localSnapshot: const SyncConflictSnapshot(
        payload: JournalSyncPayload(
          entryDate: '2026-07-28',
          timezoneOffsetMinutes: 480,
          mostImportantAccomplishment: 'Local accomplishment',
          mostDrainingEvent: null,
          emotionSource: null,
          learning: 'Local Journal',
          tomorrowAdjustment: null,
          status: JournalEntryStatus.draft,
          createdAt: 100,
        ),
        updatedAt: 700,
        deletedAt: null,
        serverVersion: 5,
        originDeviceId: null,
      ),
      remoteSnapshot: const SyncConflictSnapshot(
        payload: JournalSyncPayload(
          entryDate: '2026-07-28',
          timezoneOffsetMinutes: 480,
          mostImportantAccomplishment: 'Remote accomplishment',
          mostDrainingEvent: null,
          emotionSource: null,
          learning: 'Remote Journal',
          tomorrowAdjustment: null,
          status: JournalEntryStatus.completed,
          createdAt: 100,
        ),
        updatedAt: 800,
        deletedAt: null,
        serverVersion: 6,
        originDeviceId: null,
      ),
      remoteOperation: SyncConflictOperation.upsert,
      detectedAt: 900,
      lastSeenAt: 900,
      resolutionStatus: SyncConflictResolutionStatus.unresolved,
      resolvedAt: null,
    ),
    currentLocalSnapshot: null,
    localSnapshotChanged: false,
  );
}

SyncConflictDetails _healthDetails() {
  return SyncConflictDetails(
    record: SyncConflictRecord(
      id: _conflictId,
      scope: _scope,
      entityType: SyncEntityType.health,
      recordId: _recordId,
      localSnapshot: const SyncConflictSnapshot(
        payload: HealthSyncPayload(
          recordDate: '2026-07-28',
          timezoneOffsetMinutes: 480,
          sleepDurationMinutes: 420,
          weightKg: 65,
          waterIntakeMl: 1200,
          exerciseType: 'walk',
          exerciseDurationMinutes: 30,
          physicalStateScore: 3,
          note: 'Private local note',
          dataSource: 'manual',
          sourceRecordId: null,
          createdAt: 100,
        ),
        updatedAt: 700,
        deletedAt: null,
        serverVersion: 5,
        originDeviceId: null,
      ),
      remoteSnapshot: const SyncConflictSnapshot(
        payload: HealthSyncPayload(
          recordDate: '2026-07-28',
          timezoneOffsetMinutes: 480,
          sleepDurationMinutes: 450,
          weightKg: 66,
          waterIntakeMl: 1500,
          exerciseType: 'run',
          exerciseDurationMinutes: 45,
          physicalStateScore: 4,
          note: 'Private remote note',
          dataSource: 'manual',
          sourceRecordId: null,
          createdAt: 100,
        ),
        updatedAt: 800,
        deletedAt: null,
        serverVersion: 6,
        originDeviceId: null,
      ),
      remoteOperation: SyncConflictOperation.upsert,
      detectedAt: 900,
      lastSeenAt: 900,
      resolutionStatus: SyncConflictResolutionStatus.unresolved,
      resolvedAt: null,
    ),
    currentLocalSnapshot: null,
    localSnapshotChanged: false,
  );
}

SyncConflictRecord _record({
  SyncConflictResolutionStatus status = SyncConflictResolutionStatus.unresolved,
  SyncConflictOperation operation = SyncConflictOperation.upsert,
  PlanSyncPayload? remotePayload,
  int? remoteDeletedAt,
  int? resolvedAt,
}) {
  final effectiveRemotePayload = operation == SyncConflictOperation.upsert
      ? remotePayload ?? _payload('Remote title')
      : remotePayload;
  return SyncConflictRecord(
    id: _conflictId,
    scope: _scope,
    entityType: SyncEntityType.plan,
    recordId: _recordId,
    localSnapshot: _snapshot(title: 'Local title', updatedAt: 700, version: 5),
    remoteSnapshot: SyncConflictSnapshot(
      payload: effectiveRemotePayload,
      updatedAt: operation == SyncConflictOperation.unknownPendingPull
          ? null
          : 800,
      deletedAt: remoteDeletedAt,
      serverVersion: 6,
      originDeviceId: null,
    ),
    remoteOperation: operation,
    detectedAt: 900,
    lastSeenAt: 900,
    resolutionStatus: status,
    resolvedAt: resolvedAt,
  );
}

SyncConflictSnapshot _snapshot({
  required String title,
  required int updatedAt,
  required int version,
}) {
  return SyncConflictSnapshot(
    payload: _payload(title),
    updatedAt: updatedAt,
    deletedAt: null,
    serverVersion: version,
    originDeviceId: null,
  );
}

PlanSyncPayload _payload(String title) {
  return PlanSyncPayload(
    parentGoalId: null,
    title: title,
    description: null,
    goalLevel: PlanGoalLevel.month,
    status: PlanGoalStatus.inProgress,
    startDate: '2026-07-01',
    targetDate: '2026-07-31',
    completedAt: null,
    archivedAt: null,
    sortOrder: 0,
    createdAt: 100,
  );
}

TodaySyncPayload _todayPayload({required int mood, required String note}) {
  return TodaySyncPayload(
    recordDate: '2026-07-28',
    timezoneOffsetMinutes: 480,
    priority1: 'Protect local',
    priority1Completed: false,
    priority1GoalId: null,
    priority2: null,
    priority2Completed: false,
    priority2GoalId: null,
    priority3: null,
    priority3Completed: false,
    priority3GoalId: null,
    moodScore: mood,
    energyScore: 3,
    researchMinutes: 90,
    learningMinutes: 0,
    dailyNote: note,
    status: TodayRecordStatus.draft,
    createdAt: 100,
  );
}

SyncRunResult _result() {
  return SyncRunResult(
    direction: SyncRunDirection.twoWay,
    phases: const [SyncRunPhase.completed],
    entityResults: const [
      SyncEntityResult(
        entityType: SyncEntityType.plan,
        status: SyncEntityStatus.succeeded,
        message: 'done',
      ),
    ],
    startedAt: 1,
    completedAt: 2,
  );
}

final class _RecordingPlanSyncController extends PlanSyncController {
  _RecordingPlanSyncController({this.shouldFail = false});

  final bool shouldFail;
  final List<String> calls = [];

  @override
  PlanSyncViewState build() => const PlanSyncViewState();

  Future<SyncRunResult> _complete(String call) async {
    calls.add(call);
    if (shouldFail) throw StateError('offline');
    return _result();
  }

  @override
  Future<SyncRunResult> retryConflictHydration(String conflictId) =>
      _complete('hydrate');

  @override
  Future<SyncRunResult> adoptRemote(String conflictId) => _complete('adopt');

  @override
  Future<SyncRunResult> keepLocal(String conflictId) => _complete('keep');

  @override
  Future<SyncRunResult> retryRequestedResolution(String conflictId) =>
      _complete('retry');
}
