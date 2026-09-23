import 'package:flutter/widgets.dart';

import '../../../core/images/offline_network_image.dart';
import '../../../core/network/api_asset_uri.dart';

/// Resolves a relative API image path (e.g. `/uploads/exercise-images/…`)
/// or an absolute URL for use with [Image.network].
Uri? exerciseImageResolvedUri(String? imageUrl) => apiAssetUri(imageUrl);

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

/// Miniatury są przycinane (`BoxFit.cover`) do kwadratu o boku
/// `logicalSize`, a dekodujemy tylko po szerokości — obrazek poziomy musi
/// więc mieć szerokość boku × proporcje, żeby jego wysokość nie była
/// rozciągana. 2 pokrywa obrazki do 2:1 (ilustracje ćwiczeń mają 4:3).
const _maxCoverAspect = 2;

/// Miniatura w logicznym rozmiarze widgetu — mnoży przez DPR i przycina
/// do rozsądnego zakresu, żeby siatka ćwiczeń nie dekodowała pełnych zdjęć.
ImageProvider? exerciseThumbProvider(
  BuildContext context,
  String? imageUrl, {
  required double logicalSize,
}) {
  final px =
      (logicalSize * _maxCoverAspect * MediaQuery.devicePixelRatioOf(context))
          .round();
  return exerciseImageProvider(imageUrl, cacheWidth: px.clamp(32, 512));
}
