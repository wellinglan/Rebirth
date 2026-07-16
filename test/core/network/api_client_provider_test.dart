import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/config/app_config.dart';
import 'package:rebirth/core/config/app_config_provider.dart';
import 'package:rebirth/core/config/server_endpoint_provider.dart';
import 'package:rebirth/core/network/api_client_provider.dart';
import 'package:rebirth/features/account/data/account_api_data_source.dart';
import 'package:rebirth/features/account/data/account_repository_provider.dart';
import 'package:rebirth/features/sync/data/sync_api_data_source.dart';
import 'package:rebirth/features/sync/data/sync_repository_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late HttpServer serverA;
  late HttpServer serverB;
  var callsA = 0;
  var callsB = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    serverA = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    serverB = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    serverA.listen((request) {
      callsA += 1;
      unawaited(_respond(request, 'a'));
    });
    serverB.listen((request) {
      callsB += 1;
      unawaited(_respond(request, 'b'));
    });
  });

  tearDown(() async {
    await serverA.close(force: true);
    await serverB.close(force: true);
  });

  test('saving endpoint rebuilds ApiClient without restarting container', () async {
    final endpointA = 'http://127.0.0.1:${serverA.port}';
    final endpointB = 'http://127.0.0.1:${serverB.port}';
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig(
            apiBaseUrl: endpointA,
            enableDevLogin: true,
            appVersionLabel: 'test',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(serverEndpointControllerProvider.future);

    final accountClientA =
        (container.read(accountRemoteDataSourceProvider)
                as AccountApiDataSource)
            .apiClient;
    final syncClientA =
        (container.read(syncRemoteDataSourceProvider) as SyncApiDataSource)
            .apiClient;
    expect(identical(accountClientA, syncClientA), isTrue);

    final first = await container.read(apiClientProvider).getJson('/health');
    await container
        .read(serverEndpointControllerProvider.notifier)
        .save(endpointB);
    final second = await container.read(apiClientProvider).getJson('/health');
    final accountClientB =
        (container.read(accountRemoteDataSourceProvider)
                as AccountApiDataSource)
            .apiClient;
    final syncClientB =
        (container.read(syncRemoteDataSourceProvider) as SyncApiDataSource)
            .apiClient;

    expect(first['server'], 'a');
    expect(second['server'], 'b');
    expect(callsA, 1);
    expect(callsB, 1);
    expect(identical(accountClientB, syncClientB), isTrue);
    expect(identical(accountClientA, accountClientB), isFalse);
  });
}

Future<void> _respond(HttpRequest request, String server) async {
  request.response
    ..headers.contentType = ContentType.json
    ..write(jsonEncode({'server': server}));
  await request.response.close();
}
