import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../../core/images/offline_network_image.dart';
import '../../../../../core/network/api_asset_uri.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/plan_icons.dart';
import '../../../domain/models/custom_training_plan.dart';

/// Obraz okładki planu: świeżo wybrane [bytes] (jeszcze niewysłane) mają
/// pierwszeństwo przed adresem [url] z serwera. Bez żadnego z nich daje
/// pusty widżet — rodzic pokazuje wtedy znak planu.
class PlanCoverImage extends StatelessWidget {
  const PlanCoverImage({
    super.key,
    this.url,
    this.bytes,
    this.cacheWidth = 800,
    this.fit = BoxFit.cover,
  });

  PlanCoverImage.of(
    CustomTrainingPlan plan, {
    super.key,
    this.cacheWidth = 800,
    this.fit = BoxFit.cover,
  }) : url = plan.coverUrl,
       bytes = plan.coverBytes;

  final String? url;
  final Uint8List? bytes;

  /// Szerokość dekodowania w pikselach — miniatury nie dekodują pełnego zdjęcia.
  final int cacheWidth;
  final BoxFit fit;

  static ImageProvider? providerFor({String? url, Uint8List? bytes}) {
    if (bytes != null && bytes.isNotEmpty) return MemoryImage(bytes);
    final uri = apiAssetUri(url);
    if (uri == null) return null;
    return offlineNetworkImage(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final provider = providerFor(url: url, bytes: bytes);
    if (provider == null) return const SizedBox.shrink();
    return Image(
      image: ResizeImage.resizeIfNeeded(cacheWidth, null, provider),
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

/// Znak planu w kwadracie: zdjęcie okładki, a bez niego ikona albo litera
/// w kolorze planu.
class PlanThumb extends StatelessWidget {
  const PlanThumb({
    super.key,
    required this.plan,
    required this.color,
    this.size = 64,
    this.radius = AppRadius.lg,
  });

  final CustomTrainingPlan plan;
  final Color color;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (!plan.hasCover) {
      return PlanBadge(
        name: plan.name,
        color: color,
        iconKey: plan.iconKey,
        size: size,
        radius: radius,
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1.5),
        child: ColoredBox(
          color: AppColors.surfaceVariant,
          child: SizedBox.expand(
            child: PlanCoverImage.of(plan, cacheWidth: (size * 3).round()),
          ),
        ),
      ),
    );
  }
}
