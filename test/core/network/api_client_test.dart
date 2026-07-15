import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/network/api_client.dart';
import 'package:rebirth/core/network/api_exception.dart';

void main() {
  late HttpServer server;
  late Future<void> Function(HttpRequest request) handler;
  late DioApiClient client;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    handler = (request) => _jsonResponse(request, {'status': 'ok'});
    server.listen((request) => unawaited(handler(request)));
    client = DioApiClient(baseUrl: 'http://127.0.0.1:${server.port}');
  });

  tearDown(() => server.close(force: true));

  test('GET JSON succeeds and parses a map', () async {
    String? method;
    String? path;
    handler = (request) async {
      method = request.method;
      path = request.uri.path;
      await _jsonResponse(request, {'status': 'ok', 'service': 'rebirth-api'});
    };

    final response = await client.getJson('/health');

    expect(method, 'GET');
    expect(path, '/health');
    expect(response['service'], 'rebirth-api');
  });

  test('POST JSON sends and parses a map', () async {
    Map<String, Object?>? received;
    handler = (request) async {
      received = Map<String, Object?>.from(
        jsonDecode(await utf8.decoder.bind(request).join()) as Map,
      );
      await _jsonResponse(request, {'accepted': true});
    };

    final response = await client.postJson(
      '/auth/dev-login',
      body: const {'dev_user_key': 'local-test-user'},
    );

    expect(received?['dev_user_key'], 'local-test-user');
    expect(response['accepted'], isTrue);
  });

  test('Authorization bearer header is added only when requested', () async {
    String? authorization;
    handler = (request) async {
      authorization = request.headers.value(HttpHeaders.authorizationHeader);
      await _jsonResponse(request, {'device_id': 'device-1'});
    };

    await client.postJson(
      '/devices/register',
      body: const {},
      accessToken: 'test-access-token',
    );

    expect(authorization, 'Bearer test-access-token');
  });

  test('token is never exposed by an error message', () async {
    handler = (request) => _jsonResponse(request, {
      'detail': 'test-access-token',
    }, statusCode: 500);

    final error = await _captureApiException(
      client.getJson('/failure', accessToken: 'test-access-token'),
    );

    expect(error.toString(), isNot(contains('test-access-token')));
    expect(error.message, isNot(contains('test-access-token')));
  });

  test('receive timeout becomes a network ApiException', () async {
    handler = (request) async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      try {
        await _jsonResponse(request, {'status': 'late'});
      } on HttpException {
        // The client is expected to close the request after timing out.
      }
    };

    final error = await _captureApiException(
      client.getJson('/slow', timeout: const Duration(milliseconds: 20)),
    );

    expect(error.isNetworkError, isTrue);
    expect(error.message, contains('请求超时'));
  });

  test('500 becomes a sanitized ApiException', () async {
    handler = (request) => _jsonResponse(request, {}, statusCode: 500);

    final error = await _captureApiException(client.getJson('/failure'));

    expect(error.statusCode, 500);
    expect(error.isUnauthorized, isFalse);
    expect(error.message, contains('500'));
  });

  test('401 is marked unauthorized', () async {
    handler = (request) => _jsonResponse(request, {}, statusCode: 401);

    final error = await _captureApiException(client.getJson('/protected'));

    expect(error.statusCode, 401);
    expect(error.isUnauthorized, isTrue);
  });
}

Future<void> _jsonResponse(
  HttpRequest request,
  Map<String, Object?> body, {
  int statusCode = 200,
}) async {
  request.response
    ..statusCode = statusCode
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  await request.response.close();
}

Future<ApiException> _captureApiException(Future<Object?> request) async {
  try {
    await request;
  } on ApiException catch (error) {
    return error;
  }
  throw TestFailure('Expected ApiException.');
}
