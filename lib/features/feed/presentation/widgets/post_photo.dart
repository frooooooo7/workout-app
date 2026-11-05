import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/images/offline_network_image.dart';
import '../../../../core/network/api_asset_uri.dart';
import '../../../../core/theme/app_colors.dart';

/// Zdjęcie posta w zaokrąglonej ramce o stałych proporcjach. [bytes]
/// (świeżo wybrane, jeszcze niewysłane) mają pierwszeństwo przed [url].
/// Stuknięcie otwiera podgląd na cały ekran.
class PostPhoto extends StatelessWidget {
  const PostPhoto({
    super.key,
    this.url,
    this.bytes,
    this.aspectRatio = 3 / 2,
    this.radius = 18,
    this.expandable = true,
  });

  final String? url;
  final Uint8List? bytes;
  final double aspectRatio;
  final double radius;
  final bool expandable;

  ImageProvider? _provider() {
    final raw = bytes;
    if (raw != null && raw.isNotEmpty) return MemoryImage(raw);
    final uri = apiAssetUri(url);
    if (uri == null) return null;
    return offlineNetworkImage(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider();
    if (provider == null) return const SizedBox.shrink();
    final width = MediaQuery.sizeOf(context).width;
    final cacheWidth = (width * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(320, 1600);

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ColoredBox(
          color: AppColors.surfaceVariant,
          child: Image(
            image: ResizeImage.resizeIfNeeded(cacheWidth, null, provider),
            fit: BoxFit.cover,
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
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.textMuted,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );

    if (!expandable) return image;
    return Semantics(
      button: true,
      label: 'Zdjęcie z treningu. Otwórz na pełnym ekranie',
      child: GestureDetector(
        onTap: () => _openViewer(context, provider),
        child: image,
      ),
    );
  }

  void _openViewer(BuildContext context, ImageProvider provider) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: _PhotoViewer(provider: provider),
        ),
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.provider});

  final ImageProvider provider;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: InteractiveViewer(
                maxScale: 4,
                child: Center(child: Image(image: provider)),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  tooltip: 'Zamknij',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
