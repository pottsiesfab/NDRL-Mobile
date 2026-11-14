class AppConfig {
  AppConfig._();

  // Defaults to DEV for safety.
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static const String baseUrl = environment == 'prod'
      ? 'https://nostalgiadragleague.com'
      : 'https://dev.nostalgiadragleague.com';

  static const bool isDev = environment == 'dev';
  static const bool isProd = environment == 'prod';

  // Builds a complete API URL.
  static Uri apiUri(String path, {Map<String, String>? queryParameters}) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
  }
}
