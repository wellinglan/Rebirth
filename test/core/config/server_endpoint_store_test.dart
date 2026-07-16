import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/config/server_endpoint.dart';
import 'package:rebirth/core/config/server_endpoint_store_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const fallback = ServerEndpoint(
    baseUrl: 'http://127.0.0.1:8000',
    source: ServerEndpointSource.defaultValue,
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('uses build/default fallback when no saved value exists', () async {
    final endpoint = await LocalServerEndpointStore().read(fallback: fallback);
    expect(endpoint.baseUrl, fallback.baseUrl);
    expect(endpoint.source, ServerEndpointSource.defaultValue);
  });

  test('saved normalized endpoint has highest priority and survives restart', () async {
    await LocalServerEndpointStore().save(' http://192.168.1.8:8000/ ');

    final endpoint = await LocalServerEndpointStore().read(fallback: fallback);

    expect(endpoint.baseUrl, 'http://192.168.1.8:8000');
    expect(endpoint.source, ServerEndpointSource.saved);
  });

  test('clearing saved endpoint restores fallback', () async {
    final store = LocalServerEndpointStore();
    await store.save('https://api.example.com');
    await store.clear();

    expect((await store.read(fallback: fallback)).baseUrl, fallback.baseUrl);
  });

  test('invalid endpoint is never persisted', () async {
    final store = LocalServerEndpointStore();
    await expectLater(store.save('ftp://example.com'), throwsFormatException);
    expect((await store.read(fallback: fallback)).baseUrl, fallback.baseUrl);
  });
}

