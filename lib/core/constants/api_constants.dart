import 'package:flutter/foundation.dart' show kIsWeb;

/// Base URL for the gym-backend API resolved per platform:
///   Web (browser)     → http://localhost:3000
///   Android emulator  → http://10.0.2.2:3000  (maps to host localhost)
///   Physical device   → override via --dart-define=API_BASE_URL=http://192.168.x.x:3000
final String kApiBaseUrl = kIsWeb
    ? const String.fromEnvironment('API_BASE_URL',
        defaultValue: 'http://localhost:3000')
    : const String.fromEnvironment('API_BASE_URL',
        defaultValue: 'http://10.0.2.2:3000');
