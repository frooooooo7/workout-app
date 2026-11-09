import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

/// Origin serwera gym-backend (bez prefiksu API), zależnie od platformy:
///   Web (browser)     → http://localhost:3000
///   Android emulator  → http://10.0.2.2:3000  (maps to host localhost)
///   Physical device   → override via --dart-define=API_BASE_URL=http://192.168.x.x:3000
///
/// Służy do rozwijania ścieżek plików (`/uploads/...` z `imageUrl` /
/// `avatarUrl`), które backend serwuje bez prefiksu `/api/v1`.
///
/// W buildzie release adres `http://` jest dozwolony tylko dla maszyn lokalnych
/// (patrz [isCleartextApiOriginAllowed]) — hasła i token nie mogą iść
/// otwartym tekstem do serwera w internecie. Inaczej start kończy się błędem.
final String kApiOrigin = _checkedApiOrigin(
  _stripTrailingSlash(
    kIsWeb
        ? const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://localhost:3000',
          )
        : const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://10.0.2.2:3000',
          ),
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

String _checkedApiOrigin(String origin) {
  if (!isCleartextApiOriginAllowed(origin, isRelease: kReleaseMode)) {
    throw StateError(
      'API_BASE_URL musi używać https:// w buildzie release (podano: $origin). '
      'Adres http:// jest dozwolony tylko dla localhost, emulatora (10.0.2.2) '
      'i sieci lokalnej.',
    );
  }
  return origin;
}

/// Czy [origin] można użyć w buildzie ([isRelease] = release).
///
/// `https://` jest zawsze dozwolone. `http://` tylko poza release albo gdy host
/// jest lokalny: `localhost`, `127.0.0.0/8`, `10.0.2.2` (emulator Androida)
/// oraz adresy sieci prywatnych (`10.*`, `172.16–31.*`, `192.168.*`,
/// `169.254.*`) i nazwy `*.local`. Inne schematy są odrzucane w release.
bool isCleartextApiOriginAllowed(String origin, {required bool isRelease}) {
  final uri = Uri.tryParse(origin.trim());
  if (uri == null || uri.host.isEmpty) return !isRelease;
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'https') return true;
  if (!isRelease) return true;
  if (scheme != 'http') return false;
  return _isLocalHost(uri.host.toLowerCase());
}

bool _isLocalHost(String host) {
  if (host == 'localhost' || host.endsWith('.local')) return true;
  final parts = host.split('.');
  if (parts.length != 4) return false;
  final octets = parts.map(int.tryParse).toList();
  if (octets.any((o) => o == null || o < 0 || o > 255)) return false;
  final a = octets[0]!;
  final b = octets[1]!;
  return a == 127 ||
      a == 10 ||
      (a == 172 && b >= 16 && b <= 31) ||
      (a == 192 && b == 168) ||
      (a == 169 && b == 254);
}
