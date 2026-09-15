import '../constants/api_constants.dart';

/// Rozwija publiczną ścieżkę pliku z API (np. `/uploads/exercise-images/…`,
/// `/uploads/avatars/…`) do pełnego adresu. Adresy absolutne zostają bez
/// zmian; pusta wartość daje `null`.
Uri? apiAssetUri(String? path, {String? baseUrl}) {
  if (path == null || path.isEmpty) return null;
  final parsed = Uri.tryParse(path);
  if (parsed != null && parsed.hasScheme) return parsed;
  final normalized = path.startsWith('/') ? path.substring(1) : path;
  return Uri.parse(baseUrl ?? kApiBaseUrl).resolve(normalized);
}
