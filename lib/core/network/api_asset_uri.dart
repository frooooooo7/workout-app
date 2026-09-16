import '../constants/api_constants.dart';

/// Rozwija publiczną ścieżkę pliku z API (np. `/uploads/exercise-images/…`,
/// `/uploads/avatars/…`) do pełnego adresu względem originu serwera
/// ([kApiOrigin]) — pliki są serwowane bez prefiksu `/api/v1`. Adresy
/// absolutne zostają bez zmian; pusta wartość daje `null`.
Uri? apiAssetUri(String? path, {String? baseUrl}) {
  if (path == null || path.isEmpty) return null;
  final parsed = Uri.tryParse(path);
  if (parsed != null && parsed.hasScheme) return parsed;
  final normalized = path.startsWith('/') ? path.substring(1) : path;
  return Uri.parse(
    _withTrailingSlash(baseUrl ?? kApiOrigin),
  ).resolve(normalized);
}

/// `Uri.resolve` zastępuje ostatni segment bazy — origin z podścieżką
/// (np. `https://host/gym`) musi kończyć się ukośnikiem.
String _withTrailingSlash(String base) => base.endsWith('/') ? base : '$base/';
