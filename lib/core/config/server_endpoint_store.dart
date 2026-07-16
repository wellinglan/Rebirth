import 'server_endpoint.dart';

abstract interface class ServerEndpointStore {
  Future<ServerEndpoint> read({required ServerEndpoint fallback});

  Future<void> save(String baseUrl);

  Future<void> clear();
}

