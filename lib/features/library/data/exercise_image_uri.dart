import '../../../core/constants/api_constants.dart';

/// Resolves a relative API image path (e.g. `/uploads/exercise-images/…`)
/// or an absolute URL for use with [Image.network].
Uri? exerciseImageResolvedUri(String? imageUrl) {
  if (imageUrl == null || imageUrl.isEmpty) return null;
  final parsed = Uri.tryParse(imageUrl);
  if (parsed != null && parsed.hasScheme) return parsed;
  final normalized =
      imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl;
  return Uri.parse(kApiBaseUrl).resolve(normalized);
}
