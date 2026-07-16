import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/growth/data/growth_repository_provider.dart';
import 'package:rebirth/features/growth/domain/growth_period.dart';
import 'package:rebirth/features/growth/domain/growth_repository.dart';
import 'package:rebirth/features/growth/domain/growth_snapshot.dart';
import 'package:rebirth/features/growth/presentation/growth_controller.dart';

import '../growth_test_data.dart';

void main() {
  late _FakeGrowthRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _FakeGrowthRepository();
    container = ProviderContainer(
      overrides: [growthRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() => container.dispose());

  test('defaults to seven days and performs one initial query', () async {
    final state = await container.read(growthControllerProvider.future);

    expect(state.period, GrowthPeriod.sevenDays);
    expect(state.snapshot.period, GrowthPeriod.sevenDays);
    expect(repository.calls, [GrowthPeriod.sevenDays]);
  });

  test('switches to thirty days and back to seven days', () async {
    await container.read(growthControllerProvider.future);
    final notifier = container.read(growthControllerProvider.notifier);

    await notifier.selectPeriod(GrowthPeriod.thirtyDays);
    expect(
      container.read(growthControllerProvider).requireValue.period,
      GrowthPeriod.thirtyDays,
    );
    await notifier.selectPeriod(GrowthPeriod.sevenDays);

    final state = container.read(growthControllerProvider).requireValue;
    expect(state.period, GrowthPeriod.sevenDays);
    expect(repository.calls, [
      GrowthPeriod.sevenDays,
      GrowthPeriod.thirtyDays,
      GrowthPeriod.sevenDays,
    ]);
  });

  test('reselecting the current period does not query again', () async {
    await container.read(growthControllerProvider.future);

    await container
        .read(growthControllerProvider.notifier)
        .selectPeriod(GrowthPeriod.sevenDays);

    expect(repository.calls, [GrowthPeriod.sevenDays]);
  });

  test('reload queries the currently selected period', () async {
    await container.read(growthControllerProvider.future);
    final notifier = container.read(growthControllerProvider.notifier);
    await notifier.selectPeriod(GrowthPeriod.thirtyDays);

    await notifier.reload();

    expect(repository.calls, [
      GrowthPeriod.sevenDays,
      GrowthPeriod.thirtyDays,
      GrowthPeriod.thirtyDays,
    ]);
  });

  test('initial error becomes full error and retry can recover', () async {
    repository.enqueue(
      GrowthPeriod.sevenDays,
      Future<GrowthSnapshot>.error(StateError('initial failed')),
    );

    await expectLater(
      container.read(growthControllerProvider.future),
      throwsStateError,
    );
    expect(container.read(growthControllerProvider), isA<AsyncError>());

    repository.enqueue(
      GrowthPeriod.sevenDays,
      Future.value(growthTestSnapshot()),
    );
    await container.read(growthControllerProvider.notifier).reload();

    expect(container.read(growthControllerProvider), isA<AsyncData>());
    expect(repository.calls, [GrowthPeriod.sevenDays, GrowthPeriod.sevenDays]);
  });

  test(
    'refresh retains old data and shows a lightweight loading state',
    () async {
      final initial = await container.read(growthControllerProvider.future);
      final gate = Completer<GrowthSnapshot>();
      repository.enqueue(GrowthPeriod.thirtyDays, gate.future);

      final operation = container
          .read(growthControllerProvider.notifier)
          .selectPeriod(GrowthPeriod.thirtyDays);
      await Future<void>.delayed(Duration.zero);

      final refreshing = container.read(growthControllerProvider).requireValue;
      expect(refreshing.period, GrowthPeriod.thirtyDays);
      expect(refreshing.isRefreshing, isTrue);
      expect(refreshing.snapshot, same(initial.snapshot));

      gate.complete(growthTestSnapshot(period: GrowthPeriod.thirtyDays));
      await operation;
    },
  );

  test('refresh failure keeps old data and is non-blocking', () async {
    final initial = await container.read(growthControllerProvider.future);
    repository.enqueue(
      GrowthPeriod.thirtyDays,
      Future<GrowthSnapshot>.error(StateError('refresh failed')),
    );

    await container
        .read(growthControllerProvider.notifier)
        .selectPeriod(GrowthPeriod.thirtyDays);

    final state = container.read(growthControllerProvider).requireValue;
    expect(state.period, GrowthPeriod.sevenDays);
    expect(state.snapshot, same(initial.snapshot));
    expect(state.isRefreshing, isFalse);
    expect(state.refreshFailed, isTrue);
  });

  test(
    'slow thirty-day response cannot overwrite a later seven-day result',
    () async {
      await container.read(growthControllerProvider.future);
      final thirtyGate = Completer<GrowthSnapshot>();
      final sevenGate = Completer<GrowthSnapshot>();
      repository
        ..enqueue(GrowthPeriod.thirtyDays, thirtyGate.future)
        ..enqueue(GrowthPeriod.sevenDays, sevenGate.future);
      final notifier = container.read(growthControllerProvider.notifier);

      final thirtyOperation = notifier.selectPeriod(GrowthPeriod.thirtyDays);
      await Future<void>.delayed(Duration.zero);
      final sevenOperation = notifier.selectPeriod(GrowthPeriod.sevenDays);
      sevenGate.complete(growthTestSnapshot());
      await sevenOperation;
      thirtyGate.complete(growthTestSnapshot(period: GrowthPeriod.thirtyDays));
      await thirtyOperation;

      final state = container.read(growthControllerProvider).requireValue;
      expect(state.period, GrowthPeriod.sevenDays);
      expect(state.snapshot.period, GrowthPeriod.sevenDays);
    },
  );

  test(
    'slow seven-day response cannot overwrite a later thirty-day result',
    () async {
      await container.read(growthControllerProvider.future);
      await container
          .read(growthControllerProvider.notifier)
          .selectPeriod(GrowthPeriod.thirtyDays);
      final sevenGate = Completer<GrowthSnapshot>();
      final thirtyGate = Completer<GrowthSnapshot>();
      repository
        ..enqueue(GrowthPeriod.sevenDays, sevenGate.future)
        ..enqueue(GrowthPeriod.thirtyDays, thirtyGate.future);
      final notifier = container.read(growthControllerProvider.notifier);

      final sevenOperation = notifier.selectPeriod(GrowthPeriod.sevenDays);
      await Future<void>.delayed(Duration.zero);
      final thirtyOperation = notifier.selectPeriod(GrowthPeriod.thirtyDays);
      thirtyGate.complete(growthTestSnapshot(period: GrowthPeriod.thirtyDays));
      await thirtyOperation;
      sevenGate.complete(growthTestSnapshot());
      await sevenOperation;

      final state = container.read(growthControllerProvider).requireValue;
      expect(state.period, GrowthPeriod.thirtyDays);
      expect(state.snapshot.period, GrowthPeriod.thirtyDays);
    },
  );

  test('repository contract used by controller is read-only', () async {
    await container.read(growthControllerProvider.future);
    await container.read(growthControllerProvider.notifier).reload();

    expect(repository.calls, [GrowthPeriod.sevenDays, GrowthPeriod.sevenDays]);
  });
}

final class _FakeGrowthRepository implements GrowthRepository {
  final List<GrowthPeriod> calls = [];
  final Map<GrowthPeriod, List<Future<GrowthSnapshot>>> _queued = {};

  void enqueue(GrowthPeriod period, Future<GrowthSnapshot> result) {
    _queued.putIfAbsent(period, () => []).add(result);
  }

  @override
  Future<GrowthSnapshot> loadRecent(GrowthPeriod period) {
    calls.add(period);
    final queued = _queued[period];
    if (queued != null && queued.isNotEmpty) {
      return queued.removeAt(0);
    }
    return Future.value(growthTestSnapshot(period: period));
  }
}
