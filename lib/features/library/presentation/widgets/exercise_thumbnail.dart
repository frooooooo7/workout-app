import 'package:flutter/material.dart';

import '../../data/exercise_image_uri.dart';

/// Kwadratowa miniatura ćwiczenia. [placeholder] widać, gdy ćwiczenie nie ma
/// obrazka, gdy obrazek jeszcze się wczytuje albo gdy nie dało się go pobrać.
class ExerciseThumbnail extends StatelessWidget {
  const ExerciseThumbnail({
    super.key,
    required this.imageUrl,
    required this.size,
    required this.placeholder,
    this.borderRadius = 12,
    this.backgroundColor,
    this.borderColor,
  });

  final String? imageUrl;
  final double size;
  final Widget placeholder;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final provider =
        exerciseThumbProvider(context, imageUrl, logicalSize: size);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      clipBehavior: Clip.antiAlias,
      child: provider == null
          ? placeholder
          : Image(
              image: provider,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (context, error, stackTrace) => placeholder,
              // Nie loadingBuilder: obrazek z dysku (OfflineNetworkImage) nie
              // raportuje postępu, więc zamiast placeholdera byłoby puste pole.
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                  frame == null ? placeholder : child,
            ),
    );
  }
}
