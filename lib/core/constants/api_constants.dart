import 'package:flutter/foundation.dart' show kIsWeb;

/// Origin serwera gym-backend (bez prefiksu API), zależnie od platformy:
///   Web (browser)     → http://localhost:3000
///   Android emulator  → http://10.0.2.2:3000  (maps to host localhost)
///   Physical device   → override via --dart-define=API_BASE_URL=http://192.168.x.x:3000
///
/// Służy do rozwijania ścieżek plików (`/uploads/...` z `imageUrl` /
/// `avatarUrl`), które backend serwuje bez prefiksu `/api/v1`.
final String kApiOrigin = _stripTrailingSlash(
  kIsWeb
      ? const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://localhost:3000',
        )
      : const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://10.0.2.2:3000',
        ),
);

/// Prefiks wersji REST API — jedyne miejsce, gdzie jest zdefiniowany.
const String kApiVersionPrefix = '/api/v1';

/// Bazowy adres dla [ApiClient]: każda ścieżka endpointu (`/auth/login`,
/// `/training-sessions/history`, …) jest doklejana do `<origin>/api/v1`.
final String kApiBaseUrl = apiBaseUrlFor(kApiOrigin);

/// `<origin>/api/v1` dla podanego originu (także w testach E2E).
String apiBaseUrlFor(String origin) =>
    '${_stripTrailingSlash(origin)}$kApiVersionPrefix';

String _stripTrailingSlash(String value) =>
    value.endsWith('/') ? value.substring(0, value.length - 1) : value;
