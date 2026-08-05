import 'dart:collection';

import 'personal_data_backup.dart';

abstract interface class PersonalDataExportModule {
  String get id;

  Future<PersonalDataModuleSnapshot> export(String localUserId);
}

typedef PersonalDataExportBoundaryCheck = void Function();

final class PersonalDataExportModuleRegistry {
  PersonalDataExportModuleRegistry(List<PersonalDataExportModule> modules)
    : modules = UnmodifiableListView(modules) {
    final ids = modules.map((module) => module.id).toSet();
    if (ids.length != modules.length || ids.any((id) => id.trim().isEmpty)) {
      throw ArgumentError('Personal data export module IDs must be unique.');
    }
  }

  final List<PersonalDataExportModule> modules;

  Future<List<PersonalDataModuleSnapshot>> exportAll(
    String localUserId, {
    required PersonalDataExportBoundaryCheck checkBoundary,
  }) async {
    final snapshots = <PersonalDataModuleSnapshot>[];
    for (final module in modules) {
      checkBoundary();
      snapshots.add(await module.export(localUserId));
      checkBoundary();
    }
    return List.unmodifiable(snapshots);
  }
}
