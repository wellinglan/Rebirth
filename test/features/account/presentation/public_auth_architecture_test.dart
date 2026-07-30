import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'public auth widgets depend on the controller, not data infrastructure',
    () {
      for (final path in const [
        'lib/features/account/presentation/login_page.dart',
        'lib/features/account/presentation/register_page.dart',
        'lib/features/account/presentation/developer_login_page.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, isNot(contains('AppDatabase')));
        expect(source, isNot(contains('package:drift')));
        expect(source, isNot(contains('RemoteDataSource')));
        expect(source, isNot(contains('ApiClient')));
        expect(source, isNot(contains('PasswordAuthService')));
        expect(source, contains('appAuthControllerProvider'));
      }
    },
  );

  test(
    'password and access token are absent from persistent app state models',
    () {
      final authState = File(
        'lib/features/account/domain/app_auth_state.dart',
      ).readAsStringSync();
      final config = File('lib/core/config/app_config.dart').readAsStringSync();

      expect(authState, isNot(contains('final String? password')));
      expect(authState, isNot(contains('accessToken')));
      expect(authState, isNot(contains('refreshToken')));
      expect(config, isNot(contains('accessToken')));
      expect(config, isNot(contains('refreshToken')));
      expect(config, isNot(contains('password')));
    },
  );

  test(
    'public route parameters contain no credentials or account identifiers',
    () {
      final routes = File(
        'lib/core/router/route_names.dart',
      ).readAsStringSync();

      expect(routes, isNot(contains('username=')));
      expect(routes, isNot(contains('password=')));
      expect(routes, isNot(contains('token=')));
      expect(routes, isNot(contains('cloudUserId=')));
    },
  );
}
