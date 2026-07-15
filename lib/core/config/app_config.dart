final class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.enableDevLogin,
    required this.appVersionLabel,
  });

  const AppConfig.development()
    : apiBaseUrl = 'http://127.0.0.1:8000',
      enableDevLogin = true,
      appVersionLabel = '1.0.0+1';

  final String apiBaseUrl;
  final bool enableDevLogin;
  final String appVersionLabel;
}
