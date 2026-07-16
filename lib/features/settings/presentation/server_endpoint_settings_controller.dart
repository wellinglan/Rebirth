import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rebirth/core/config/server_endpoint.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';

final serverEndpointSettingsControllerProvider =
    NotifierProvider<ServerEndpointSettingsController, ServerEndpointSettingsState>(
      ServerEndpointSettingsController.new,
    );

final class ServerEndpointSettingsState {
  const ServerEndpointSettingsState({
    this.isTesting = false,
    this.testedBaseUrl,
    this.health,
    this.errorMessage,
  });

  final bool isTesting;
  final String? testedBaseUrl;
  final ServerEndpointHealth? health;
  final String? errorMessage;
}

class ServerEndpointSettingsController
    extends Notifier<ServerEndpointSettingsState> {
  @override
  ServerEndpointSettingsState build() => const ServerEndpointSettingsState();

  String? validate(String value) {
    return ref.read(serverEndpointValidatorProvider).errorFor(value);
  }

  Future<bool> testConnection(String value) async {
    final validator = ref.read(serverEndpointValidatorProvider);
    final error = validator.errorFor(value);
    if (error != null) {
      state = ServerEndpointSettingsState(errorMessage: error);
      return false;
    }
    final normalized = validator.normalize(value);
    state = const ServerEndpointSettingsState(isTesting: true);
    try {
      final health = await ref
          .read(serverEndpointConnectionTesterProvider)
          .test(normalized);
      state = ServerEndpointSettingsState(
        testedBaseUrl: normalized,
        health: health,
      );
      return true;
    } catch (_) {
      state = const ServerEndpointSettingsState(
        errorMessage: '无法连接该服务器，地址尚未保存。',
      );
      return false;
    }
  }

  bool canSave(String value) {
    try {
      final normalized = ref.read(serverEndpointValidatorProvider).normalize(value);
      return state.health?.isCompatible == true &&
          state.testedBaseUrl == normalized;
    } on FormatException {
      return false;
    }
  }

  Future<void> save(String value) {
    if (!canSave(value)) {
      throw StateError('Server endpoint must pass health check before saving.');
    }
    return ref.read(serverEndpointControllerProvider.notifier).save(value);
  }

  Future<void> restoreDefault() {
    return ref.read(serverEndpointControllerProvider.notifier).restoreDefault();
  }
}
