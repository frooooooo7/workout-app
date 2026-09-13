import 'package:flutter/widgets.dart';

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
///
/// [cacheWidth] dekoduje miniaturę w docelowej szerokości pikseli, zamiast
/// trzymać pełną rozdzielczość w [ImageCache].
ImageProvider? exerciseImageProvider(String? imageUrl, {int? cacheWidth}) {
  final uri = exerciseImageResolvedUri(imageUrl);
  if (uri == null) return null;
  final base = offlineNetworkImage(uri.toString());
  if (cacheWidth == null) return base;
  return ResizeImage.resizeIfNeeded(cacheWidth, null, base);
}

/// Miniatura w logicznym rozmiarze widgetu — mnoży przez DPR i przycina
/// do rozsądnego zakresu, żeby siatka ćwiczeń nie dekodowała pełnych zdjęć.
ImageProvider? exerciseThumbProvider(
  BuildContext context,
  String? imageUrl, {
  required double logicalSize,
}) {
  final px = (logicalSize * MediaQuery.devicePixelRatioOf(context)).round();
  return exerciseImageProvider(imageUrl, cacheWidth: px.clamp(32, 512));
}
