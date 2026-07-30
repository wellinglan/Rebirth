enum AppEnvironment { production, alpha, development, test }

final class AppConfig {
  static const defaultApiBaseUrl = 'http://127.0.0.1:8000';
  static const environmentKey = 'REBIRTH_ENV';
  static const serverEndpointKey = 'REBIRTH_SERVER_ENDPOINT';
  static const enableDevLoginKey = 'REBIRTH_ENABLE_DEV_LOGIN';
  static const legacyApiBaseUrlKey = 'REBIRTH_API_BASE_URL';

  const AppConfig({
    required this.apiBaseUrl,
    required this.enableDevLogin,
    required this.appVersionLabel,
    this.environment = AppEnvironment.development,
  });

  const AppConfig.development()
    : environment = AppEnvironment.development,
      apiBaseUrl = const String.fromEnvironment(
        legacyApiBaseUrlKey,
        defaultValue: defaultApiBaseUrl,
      ),
      enableDevLogin = true,
      appVersionLabel = '1.0.0+1';

  factory AppConfig.fromEnvironment() {
    const environmentValue = String.fromEnvironment(
      environmentKey,
      defaultValue: 'development',
    );
    const endpointValue = String.fromEnvironment(serverEndpointKey);
    const legacyEndpointValue = String.fromEnvironment(legacyApiBaseUrlKey);
    const devLoginValue = String.fromEnvironment(enableDevLoginKey);
    return AppConfig.fromValues(
      environmentValue: environmentValue,
      serverEndpoint: endpointValue,
      legacyApiBaseUrl: legacyEndpointValue,
      enableDevLoginValue: devLoginValue,
    );
  }

  factory AppConfig.fromValues({
    required String environmentValue,
    String serverEndpoint = '',
    String legacyApiBaseUrl = '',
    String enableDevLoginValue = '',
    String appVersionLabel = '1.0.0+1',
  }) {
    final environment = _parseEnvironment(environmentValue);
    if (environment == AppEnvironment.test) {
      throw StateError(
        'The test environment must be created with AppConfig.test().',
      );
    }
    final endpoint = serverEndpoint.trim();
    if ((environment == AppEnvironment.production ||
            environment == AppEnvironment.alpha) &&
        endpoint.isEmpty) {
      throw StateError(
        '$serverEndpointKey is required for ${environment.name} builds.',
      );
    }
    final developmentEndpoint = legacyApiBaseUrl.trim();
    final apiBaseUrl = endpoint.isNotEmpty
        ? endpoint
        : developmentEndpoint.isNotEmpty
        ? developmentEndpoint
        : defaultApiBaseUrl;
    final requestedDevLogin = _parseBoolean(
      enableDevLoginValue,
      defaultValue: environment == AppEnvironment.development,
    );
    return AppConfig(
      environment: environment,
      apiBaseUrl: apiBaseUrl,
      enableDevLogin:
          environment != AppEnvironment.production && requestedDevLogin,
      appVersionLabel: appVersionLabel,
    );
  }

  const AppConfig.test({
    this.apiBaseUrl = 'https://api.example.invalid',
    this.enableDevLogin = false,
    this.appVersionLabel = 'test',
  }) : environment = AppEnvironment.test;

  final AppEnvironment environment;
  final String apiBaseUrl;
  final bool enableDevLogin;
  final String appVersionLabel;

  bool get isProduction => environment == AppEnvironment.production;

  bool get isAlpha => environment == AppEnvironment.alpha;

  static AppEnvironment _parseEnvironment(String value) {
    return switch (value.trim().toLowerCase()) {
      'production' => AppEnvironment.production,
      'alpha' => AppEnvironment.alpha,
      'development' || '' => AppEnvironment.development,
      'test' => AppEnvironment.test,
      _ => throw StateError('Unsupported $environmentKey value.'),
    };
  }

  static bool _parseBoolean(String value, {required bool defaultValue}) {
    return switch (value.trim().toLowerCase()) {
      '' => defaultValue,
      'true' => true,
      'false' => false,
      _ => throw StateError('$enableDevLoginKey must be true or false.'),
    };
  }
}
