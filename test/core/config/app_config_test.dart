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
}
