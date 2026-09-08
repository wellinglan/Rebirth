import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sync_module.dart';

typedef LocalSyncMutationSignal = void Function(SyncModuleId moduleId);

final class LocalSyncMutationBus {
  final StreamController<SyncModuleId> _events =
      StreamController<SyncModuleId>.broadcast(sync: true);

  Stream<SyncModuleId> get events => _events.stream;

  void publish(SyncModuleId moduleId) => _events.add(moduleId);

  Future<void> close() => _events.close();
}

final localSyncMutationBusProvider = Provider<LocalSyncMutationBus>((ref) {
  final bus = LocalSyncMutationBus();
  ref.onDispose(bus.close);
  return bus;
});

final localSyncMutationSignalProvider = Provider<LocalSyncMutationSignal>((
  ref,
) {
  final bus = ref.watch(localSyncMutationBusProvider);
  return bus.publish;
});
