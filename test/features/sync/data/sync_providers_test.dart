import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/database/app_database.dart';
import 'package:rebirth/core/database/database_provider.dart';
import 'package:rebirth/features/sync/data/sync_providers.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';

void main() {
  test('provider composition registers Profile, Today, Journal, and Plan', () {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    final registry = container.read(syncEntityAdapterRegistryProvider);

    expect(registry.registeredTypes, [
      SyncEntityType.profile,
      SyncEntityType.today,
      SyncEntityType.journal,
      SyncEntityType.plan,
    ]);
    expect(
      registry.adapterFor(SyncEntityType.profile).entityType,
      SyncEntityType.profile,
    );
    expect(
      registry.adapterFor(SyncEntityType.today).entityType,
      SyncEntityType.today,
    );
    expect(
      registry.adapterFor(SyncEntityType.journal).entityType,
      SyncEntityType.journal,
    );
    expect(
      registry.adapterFor(SyncEntityType.plan).entityType,
      SyncEntityType.plan,
    );
    for (final type in const [SyncEntityType.health]) {
      expect(
        () => registry.adapterFor(type),
        throwsA(isA<SyncUnsupportedEntityException>()),
        reason: '${type.wireName} must not be registered in Sprint 11B',
      );
    }
  });
}
