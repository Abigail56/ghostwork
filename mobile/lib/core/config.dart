/// API base URL. Override at build/run time:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000   (Android emulator)
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');

/// Public web app URL (used to open the full Terms of Service and the builder).
const webAppUrl = String.fromEnvironment('WEB_APP_URL', defaultValue: 'http://localhost:3000');

const termsVersion = '2026-10-30';
