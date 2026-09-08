import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sync_execution_gate.dart';

final syncExecutionGateProvider = Provider<SyncExecutionGate>((ref) {
  return SyncExecutionGate();
});
