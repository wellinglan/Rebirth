import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_models.dart';
import 'package:rebirth/features/sync/presentation/sync_conflict_resolution_handlers.dart';

void main() {
  test('registry resolves all supported user modules without a fallback', () {
    final profile = _FakeHandler(SyncEntityType.profile);
    final plan = _FakeHandler(SyncEntityType.plan);
    final today = _FakeHandler(SyncEntityType.today);
    final journal = _FakeHandler(SyncEntityType.journal);
    final prompt = _FakeHandler(SyncEntityType.journalPromptConfiguration);
    final health = _FakeHandler(SyncEntityType.health);
    final registry = SyncConflictResolutionHandlerRegistry([
      profile,
      plan,
      today,
      journal,
      prompt,
      health,
    ]);

    expect(registry.handlerFor(SyncEntityType.profile), same(profile));
    expect(registry.handlerFor(SyncEntityType.plan), same(plan));
    expect(registry.handlerFor(SyncEntityType.today), same(today));
    expect(registry.handlerFor(SyncEntityType.journal), same(journal));
    expect(
      registry.handlerFor(SyncEntityType.journalPromptConfiguration),
      same(prompt),
    );
    expect(registry.handlerFor(SyncEntityType.health), same(health));
  });

  test('handler operations remain explicitly entity-scoped', () async {
    final today = _FakeHandler(SyncEntityType.today);
    final registry = SyncConflictResolutionHandlerRegistry([today]);
    final handler = registry.handlerFor(SyncEntityType.today)!;

    await handler.retryHydration('conflict');
    await handler.adoptRemote('conflict');
    await handler.keepLocal('conflict');
    await handler.retryRequestedResolution('conflict');

    expect(today.calls, ['hydrate', 'adopt', 'keep', 'retry']);
  });
}

final class _FakeHandler implements SyncConflictResolutionHandler {
  _FakeHandler(this.entityType);

  @override
  final SyncEntityType entityType;

  final List<String> calls = [];

  @override
  bool get isBusy => false;

  @override
  String? get resolvingConflictId => null;

  @override
  Future<SyncRunResult> retryHydration(String conflictId) {
    calls.add('hydrate');
    return Future.value(_result());
  }

  @override
  Future<SyncRunResult> adoptRemote(String conflictId) {
    calls.add('adopt');
    return Future.value(_result());
  }

  @override
  Future<SyncRunResult> keepLocal(String conflictId) {
    calls.add('keep');
    return Future.value(_result());
  }

  @override
  Future<SyncRunResult> retryRequestedResolution(String conflictId) {
    calls.add('retry');
    return Future.value(_result());
  }

  SyncRunResult _result() {
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
}
