import 'sync_entity_type.dart';

final class SyncFieldGroup {
  SyncFieldGroup({required this.id, required Iterable<String> keys})
    : keys = Set.unmodifiable(keys) {
    if (id.trim().isEmpty ||
        this.keys.isEmpty ||
        this.keys.any((e) => e.isEmpty)) {
      throw ArgumentError('A sync field group needs an id and field keys.');
    }
  }

  final String id;
  final Set<String> keys;
}

abstract interface class SyncMergePolicy {
  SyncEntityType get entityType;

  List<SyncFieldGroup> get fieldGroups;

  Set<String> get derivedKeys;
}

final class MapSyncMergePolicy implements SyncMergePolicy {
  MapSyncMergePolicy({
    required this.entityType,
    required Iterable<SyncFieldGroup> fieldGroups,
    Iterable<String> derivedKeys = const [],
  }) : fieldGroups = List.unmodifiable(fieldGroups),
       derivedKeys = Set.unmodifiable(derivedKeys) {
    final ids = <String>{};
    final keys = <String>{};
    for (final group in this.fieldGroups) {
      if (!ids.add(group.id) || group.keys.any((key) => !keys.add(key))) {
        throw ArgumentError('Sync field groups must be unique and disjoint.');
      }
    }
    if (keys.intersection(this.derivedKeys).isNotEmpty) {
      throw ArgumentError('Derived keys cannot belong to a merge group.');
    }
  }

  @override
  final SyncEntityType entityType;

  @override
  final List<SyncFieldGroup> fieldGroups;

  @override
  final Set<String> derivedKeys;
}
