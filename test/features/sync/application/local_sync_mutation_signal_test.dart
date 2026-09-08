import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/sync/application/local_sync_mutation_signal.dart';
import 'package:rebirth/features/sync/domain/sync_module.dart';

void main() {
  test('mutation bus publishes module events synchronously in order', () async {
    final bus = LocalSyncMutationBus();
    addTearDown(bus.close);
    final events = <SyncModuleId>[];
    final subscription = bus.events.listen(events.add);
    addTearDown(subscription.cancel);

    bus.publish(SyncModuleId.journal);
    bus.publish(SyncModuleId.health);

    expect(events, [SyncModuleId.journal, SyncModuleId.health]);
  });

  test('remote data apply cannot emit presentation mutation signals', () {
    final dataFiles = Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) =>
              file.path.endsWith('.dart') &&
              file.path.split(Platform.pathSeparator).contains('data'),
        );

    for (final file in dataFiles) {
      expect(
        file.readAsStringSync(),
        isNot(contains('local_sync_mutation_signal.dart')),
        reason: '${file.path} must not turn remote apply into a local mutation',
      );
    }
  });

  test('Sync Center widget stays outside database and repository layers', () {
    final source = File(
      'lib/features/sync/presentation/sync_center_page.dart',
    ).readAsStringSync();

    for (final forbidden in const [
      'package:drift',
      'app_database.dart',
      'repository_impl.dart',
      'SyncCoordinator',
    ]) {
      expect(source, isNot(contains(forbidden)));
    }
  });
}
