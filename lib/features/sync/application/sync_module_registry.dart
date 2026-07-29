import '../domain/sync_entity_type.dart';
import '../domain/sync_module.dart';

final class SyncModuleRegistry {
  SyncModuleRegistry(Iterable<SyncModuleDescriptor> descriptors)
    : _descriptors = _validate(descriptors);

  final List<SyncModuleDescriptor> _descriptors;

  List<SyncModuleDescriptor> get orderedModules => _descriptors;

  SyncModuleDescriptor descriptorFor(SyncModuleId moduleId) {
    return _descriptors.firstWhere(
      (descriptor) => descriptor.moduleId == moduleId,
      orElse: () => throw ArgumentError('Unknown sync module: $moduleId'),
    );
  }

  SyncModuleId? moduleForEntity(SyncEntityType entityType) {
    for (final descriptor in _descriptors) {
      if (descriptor.entityTypes.contains(entityType)) {
        return descriptor.moduleId;
      }
    }
    return null;
  }

  static List<SyncModuleDescriptor> _validate(
    Iterable<SyncModuleDescriptor> descriptors,
  ) {
    final values = descriptors.toList(growable: false);
    final ids = <SyncModuleId>{};
    for (final descriptor in values) {
      if (!ids.add(descriptor.moduleId)) {
        throw ArgumentError('Duplicate sync module: ${descriptor.moduleId}');
      }
      if (descriptor.entityTypes.isEmpty) {
        throw ArgumentError('A sync module must contain an entity type.');
      }
    }
    final ordered = values.toList()
      ..sort((left, right) => left.displayOrder.compareTo(right.displayOrder));
    return List.unmodifiable(ordered);
  }
}

SyncModuleRegistry createDefaultSyncModuleRegistry() {
  return SyncModuleRegistry([
    SyncModuleDescriptor(
      moduleId: SyncModuleId.profile,
      displayName: 'Profile',
      description: '个人资料与成长方向',
      displayOrder: 10,
      entityTypes: const [SyncEntityType.profile],
      sensitivity: SyncModuleSensitivity.standard,
    ),
    SyncModuleDescriptor(
      moduleId: SyncModuleId.plan,
      displayName: 'Plan',
      description: '目标、层级与完成状态',
      displayOrder: 20,
      entityTypes: const [SyncEntityType.plan],
      sensitivity: SyncModuleSensitivity.standard,
    ),
    SyncModuleDescriptor(
      moduleId: SyncModuleId.today,
      displayName: 'Today',
      description: '每日重点与状态记录',
      displayOrder: 30,
      entityTypes: const [SyncEntityType.today],
      sensitivity: SyncModuleSensitivity.standard,
    ),
    SyncModuleDescriptor(
      moduleId: SyncModuleId.journal,
      displayName: 'Journal',
      description: '问题配置与 Journal 记录',
      displayOrder: 40,
      entityTypes: const [
        SyncEntityType.journalPromptConfiguration,
        SyncEntityType.journal,
      ],
      sensitivity: SyncModuleSensitivity.sensitive,
    ),
    SyncModuleDescriptor(
      moduleId: SyncModuleId.health,
      displayName: 'Health',
      description: '健康记录，包含敏感个人数据',
      displayOrder: 50,
      entityTypes: const [SyncEntityType.health],
      sensitivity: SyncModuleSensitivity.sensitive,
    ),
  ]);
}
