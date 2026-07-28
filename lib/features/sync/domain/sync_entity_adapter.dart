import 'sync_conflict.dart';
import 'sync_entity_type.dart';
import 'sync_models.dart';

abstract interface class SyncEntityAdapter {
  SyncEntityType get entityType;

  Future<List<SyncPushItem>> collectPending();

  Map<String, Object?> encodePayload(SyncEntityPayload payload);

  SyncChange decodeRemoteChange({
    required String recordId,
    required Map<String, Object?> payload,
    required int updatedAt,
    required int? deletedAt,
    required String originDeviceId,
    required int serverVersion,
  });

  Future<SyncEntityResult> acknowledgePush({
    required List<SyncPushItem> submitted,
    required List<SyncAcknowledgement> accepted,
    required List<SyncConflict> conflicts,
    required int syncedAt,
  });

  Future<SyncEntityResult> applyRemoteChanges({
    required List<SyncChange> changes,
    required int syncedAt,
    SyncPullMode pullMode = SyncPullMode.incremental,
  });
}

final class SyncEntityAdapterRegistry {
  SyncEntityAdapterRegistry(Iterable<SyncEntityAdapter> adapters)
    : _adapters = _buildRegistry(adapters);

  final Map<SyncEntityType, SyncEntityAdapter> _adapters;

  List<SyncEntityType> get registeredTypes => List.unmodifiable(_adapters.keys);

  SyncEntityAdapter adapterFor(SyncEntityType entityType) {
    final adapter = _adapters[entityType];
    if (adapter == null) {
      throw SyncUnsupportedEntityException(entityType.wireName);
    }
    return adapter;
  }

  static Map<SyncEntityType, SyncEntityAdapter> _buildRegistry(
    Iterable<SyncEntityAdapter> adapters,
  ) {
    final registry = <SyncEntityType, SyncEntityAdapter>{};
    for (final adapter in adapters) {
      if (registry.containsKey(adapter.entityType)) {
        throw StateError(
          'Duplicate sync adapter for ${adapter.entityType.wireName}.',
        );
      }
      registry[adapter.entityType] = adapter;
    }
    return Map.unmodifiable(registry);
  }
}
