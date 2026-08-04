import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/sync/application/sync_module_registry.dart';
import 'package:rebirth/features/sync/domain/sync_entity_type.dart';
import 'package:rebirth/features/sync/domain/sync_module.dart';

void main() {
  test('default registry has stable explicit product order and IDs', () {
    final registry = createDefaultSyncModuleRegistry();

    expect(
      registry.orderedModules.map((item) => item.moduleId.stableId),
      const [
        'module.profile',
        'module.plan',
        'module.today',
        'module.journal',
        'module.health',
        'module.ai_report',
      ],
    );
    expect(registry.orderedModules.map((item) => item.displayOrder), const [
      10,
      20,
      30,
      40,
      50,
      60,
    ]);
  });

  test('Journal groups configuration before entry and Health is sensitive', () {
    final registry = createDefaultSyncModuleRegistry();

    expect(registry.descriptorFor(SyncModuleId.journal).entityTypes, const [
      SyncEntityType.journalPromptConfiguration,
      SyncEntityType.journal,
    ]);
    expect(
      registry.descriptorFor(SyncModuleId.health).sensitivity,
      SyncModuleSensitivity.sensitive,
    );
    expect(
      registry.moduleForEntity(SyncEntityType.journalPromptConfiguration),
      SyncModuleId.journal,
    );
  });

  test('registry rejects duplicate IDs and exposes immutable ordering', () {
    final profile = _descriptor(SyncModuleId.profile, 20);

    expect(
      () =>
          SyncModuleRegistry([profile, _descriptor(SyncModuleId.profile, 10)]),
      throwsArgumentError,
    );
    final registry = SyncModuleRegistry([
      profile,
      _descriptor(SyncModuleId.plan, 10),
    ]);
    expect(registry.orderedModules.map((item) => item.moduleId), const [
      SyncModuleId.plan,
      SyncModuleId.profile,
    ]);
    expect(
      () => registry.orderedModules.add(_descriptor(SyncModuleId.today, 30)),
      throwsUnsupportedError,
    );
    expect(
      () => registry.descriptorFor(SyncModuleId.health),
      throwsArgumentError,
    );
  });
}

SyncModuleDescriptor _descriptor(SyncModuleId id, int order) {
  final entity = switch (id) {
    SyncModuleId.profile => SyncEntityType.profile,
    SyncModuleId.plan => SyncEntityType.plan,
    SyncModuleId.today => SyncEntityType.today,
    SyncModuleId.journal => SyncEntityType.journal,
    SyncModuleId.health => SyncEntityType.health,
    SyncModuleId.aiReport => SyncEntityType.aiReport,
  };
  return SyncModuleDescriptor(
    moduleId: id,
    displayName: id.name,
    description: id.name,
    displayOrder: order,
    entityTypes: [entity],
    sensitivity: SyncModuleSensitivity.standard,
  );
}
