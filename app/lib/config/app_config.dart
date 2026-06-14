/// App-wide configuration.
///
/// Override the API base URL at build time:
///   flutter run --dart-define=API_BASE_URL=https://api.yourhost.com
///
/// Defaults assume a backend on your dev machine. Note: the Android emulator
/// reaches the host machine via 10.0.2.2, not localhost.
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:4000',
  );

  static String get apiRoot => '$apiBaseUrl/api';
}
