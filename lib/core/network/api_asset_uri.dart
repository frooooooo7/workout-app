import '../constants/api_constants.dart';

/// Resolves a relative API asset path (e.g. `/uploads/avatar-images/…`)
/// or an absolute URL for use with [Image.network].
Uri? resolveApiAssetUri(String? url) {
  if (url == null || url.isEmpty) return null;
  final parsed = Uri.tryParse(url);
  if (parsed != null && parsed.hasScheme) return parsed;
  final normalized =
      url.startsWith('/') ? url.substring(1) : url;
  return Uri.parse(kApiBaseUrl).resolve(normalized);
}

String? resolveApiAssetUrl(String? url) => resolveApiAssetUri(url)?.toString();
