import 'package:flutter_test/flutter_test.dart';
import 'package:rebirth/core/config/app_config.dart';

void main() {
  test('development config targets the local Rebirth API', () {
    const config = AppConfig.development();

    expect(config.apiBaseUrl, 'http://127.0.0.1:8000');
    expect(config.enableDevLogin, isTrue);
    expect(config.appVersionLabel, '1.0.0+1');
  });

  test('config supports later environment-specific values', () {
    const config = AppConfig(
      apiBaseUrl: 'https://api.example.invalid',
      enableDevLogin: false,
      appVersionLabel: '2.0.0',
    );

    expect(config.apiBaseUrl, 'https://api.example.invalid');
    expect(config.enableDevLogin, isFalse);
  });

  test('production always disables developer login', () {
    final config = AppConfig.fromValues(
      environmentValue: 'production',
      serverEndpoint: 'https://api.example.invalid',
      enableDevLoginValue: 'true',
    );

    expect(config.environment, AppEnvironment.production);
    expect(config.enableDevLogin, isFalse);
    expect(config.isAlpha, isFalse);
  });

  test('production fails closed without a server endpoint', () {
    expect(
      () => AppConfig.fromValues(environmentValue: 'production'),
      throwsStateError,
    );
  });

  test('alpha requires explicit developer login enablement', () {
    final disabled = AppConfig.fromValues(
      environmentValue: 'alpha',
      serverEndpoint: 'https://api.example.invalid',
    );
    final enabled = AppConfig.fromValues(
      environmentValue: 'alpha',
      serverEndpoint: 'https://api.example.invalid',
      enableDevLoginValue: 'true',
    );

    expect(disabled.isAlpha, isTrue);
    expect(disabled.enableDevLogin, isFalse);
    expect(enabled.enableDevLogin, isTrue);
  });

  test(
    'test config is dependency-injected and does not parse build values',
    () {
      const config = AppConfig.test(enableDevLogin: true);

      expect(config.environment, AppEnvironment.test);
      expect(config.enableDevLogin, isTrue);
      expect(
        () => AppConfig.fromValues(environmentValue: 'test'),
        throwsStateError,
      );
    },
  );

  test('unsupported build values fail closed', () {
    expect(
      () => AppConfig.fromValues(environmentValue: 'preview'),
      throwsStateError,
    );
    expect(
      () => AppConfig.fromValues(
        environmentValue: 'development',
        enableDevLoginValue: 'yes',
      ),
      throwsStateError,
    );
  });
}
