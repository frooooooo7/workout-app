import 'package:flutter/painting.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/images/offline_network_image.dart';

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

/// Obrazek ćwiczenia zapisywany na dysku (widoczny także offline) albo
/// `null`, gdy ćwiczenie nie ma zdjęcia. Rozwija ścieżki względne z API —
/// surowy `NetworkImage('/uploads/…')` nigdy się nie wczytywał.
ImageProvider? exerciseImageProvider(String? imageUrl) {
  final uri = exerciseImageResolvedUri(imageUrl);
  return uri == null ? null : offlineNetworkImage(uri.toString());
}
