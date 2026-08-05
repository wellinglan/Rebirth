import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/personal_data_export/data/personal_data_export_providers.dart';
import 'package:rebirth/features/personal_data_export/domain/full_personal_data_export.dart';
import 'package:rebirth/features/personal_data_export/presentation/full_personal_data_export_controller.dart';

void main() {
  test('exporting state blocks concurrent operations', () async {
    final completer = Completer<FullPersonalDataExportResult>();
    final service = _FakeService([() => completer.future]);
    final container = ProviderContainer(
      overrides: [
        fullPersonalDataExportServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      fullPersonalDataExportControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(
      fullPersonalDataExportControllerProvider.notifier,
    );

    final first = controller.export();
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(fullPersonalDataExportControllerProvider).isExporting,
      isTrue,
    );
    expect((await controller.export()).isExporting, isTrue);
    expect(service.calls, 1);

    completer.complete(
      const FullPersonalDataExportResult(
        disposition: FullPersonalDataExportDisposition.saved,
        moduleCount: 7,
        recordCount: 42,
      ),
    );
    final state = await first;
    expect(state.phase, FullPersonalDataExportPhase.saved);
    expect(state.recordCount, 42);
  });

  test('controlled failure hides internals and allows retry', () async {
    final service = _FakeService([
      () => Future.error(
        const FullPersonalDataExportException(
          FullPersonalDataExportFailure.storageUnavailable,
        ),
      ),
      () => Future.value(
        const FullPersonalDataExportResult(
          disposition: FullPersonalDataExportDisposition.saved,
          moduleCount: 7,
          recordCount: 2,
        ),
      ),
    ]);
    final container = ProviderContainer(
      overrides: [
        fullPersonalDataExportServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      fullPersonalDataExportControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(
      fullPersonalDataExportControllerProvider.notifier,
    );

    final failed = await controller.export();
    expect(failed.phase, FullPersonalDataExportPhase.failed);
    expect(failed.message, isNot(contains('Exception')));
    expect(failed.message, isNot(contains(r'C:\')));
    expect(
      (await controller.export()).phase,
      FullPersonalDataExportPhase.saved,
    );
    expect(service.calls, 2);
  });
}

final class _FakeService implements FullPersonalDataExportService {
  _FakeService(this.results);

  final List<Future<FullPersonalDataExportResult> Function()> results;
  int calls = 0;

  @override
  Future<FullPersonalDataExportResult> export() {
    calls += 1;
    return results.removeAt(0)();
  }
}
