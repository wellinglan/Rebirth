enum SyncExecutionOrigin { manual, automatic }

final class SyncExecutionInProgressException implements Exception {
  const SyncExecutionInProgressException(this.activeOrigin);

  final SyncExecutionOrigin activeOrigin;

  @override
  String toString() => 'A ${activeOrigin.name} sync execution is in progress.';
}

final class SyncExecutionGate {
  Future<Object?>? _activeExecution;
  SyncExecutionOrigin? _activeOrigin;

  bool get isRunning => _activeExecution != null;

  SyncExecutionOrigin? get activeOrigin => _activeOrigin;

  Future<void> get whenIdle async {
    final active = _activeExecution;
    if (active == null) return;
    try {
      await active;
    } catch (_) {
      // Waiting for availability must not surface the previous run's failure.
    }
  }

  Future<T> run<T>({
    required SyncExecutionOrigin origin,
    required Future<T> Function() operation,
  }) {
    if (_activeExecution != null) {
      throw SyncExecutionInProgressException(_activeOrigin!);
    }

    final future = Future<T>.sync(operation);
    _activeExecution = future;
    _activeOrigin = origin;
    void clear() {
      if (identical(_activeExecution, future)) {
        _activeExecution = null;
        _activeOrigin = null;
      }
    }

    future.then<void>(
      (_) => clear(),
      onError: (Object _, StackTrace _) => clear(),
    );
    return future;
  }
}
