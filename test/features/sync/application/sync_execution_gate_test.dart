import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/features/sync/application/sync_execution_gate.dart';

void main() {
  test('gate allows only one execution across origins', () async {
    final gate = SyncExecutionGate();
    final completer = Completer<int>();

    final automatic = gate.run(
      origin: SyncExecutionOrigin.automatic,
      operation: () => completer.future,
    );

    expect(gate.isRunning, isTrue);
    expect(gate.activeOrigin, SyncExecutionOrigin.automatic);
    expect(
      () => gate.run(
        origin: SyncExecutionOrigin.manual,
        operation: () async => 2,
      ),
      throwsA(
        isA<SyncExecutionInProgressException>().having(
          (error) => error.activeOrigin,
          'activeOrigin',
          SyncExecutionOrigin.automatic,
        ),
      ),
    );

    completer.complete(1);
    expect(await automatic, 1);
    await gate.whenIdle;
    expect(gate.isRunning, isFalse);
  });

  test('whenIdle absorbs the active operation failure', () async {
    final gate = SyncExecutionGate();
    final completer = Completer<void>();
    final run = gate.run(
      origin: SyncExecutionOrigin.manual,
      operation: () => completer.future,
    );
    final idle = gate.whenIdle;

    completer.completeError(StateError('failed'));
    await expectLater(run, throwsStateError);
    await idle;

    expect(gate.isRunning, isFalse);
  });
}
