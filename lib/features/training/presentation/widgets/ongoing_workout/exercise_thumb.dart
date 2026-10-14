import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../library/data/exercise_image_uri.dart';
import 'workout_colors.dart';

/// Miniatura ćwiczenia. Dekodowany obraz jest trzymany między przebudowami,
/// więc odhaczanie serii nie mruga zdjęciem.
class ExerciseThumb extends StatefulWidget {
  const ExerciseThumb({
    super.key,
    required this.imageUrl,
    required this.size,
    required this.radius,
    this.opacity = 1,
    this.fallbackIcon = Icons.fitness_center,
  });

  final String? imageUrl;
  final double size;
  final double radius;
  final double opacity;

  /// Ikona, gdy ćwiczenie nie ma zdjęcia (kardio — biegacz).
  final IconData fallbackIcon;

  @override
  State<ExerciseThumb> createState() => _ExerciseThumbState();
}

class _ExerciseThumbState extends State<ExerciseThumb> {
  DecorationImage? _image;
  String? _url;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cache();
  }

  @override
  void didUpdateWidget(covariant ExerciseThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _cache();
  }

  void _cache() {
    final url = widget.imageUrl;
    if (_image != null && _url == url) return;
    _url = url;
    final provider = exerciseThumbProvider(
      context,
      url,
      logicalSize: widget.size,
    );
    _image = provider == null
        ? null
        : DecorationImage(
            image: provider,
            fit: BoxFit.cover,
            opacity: widget.opacity,
            onError: (_, _) {},
          );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: WorkoutColors.field,
        borderRadius: BorderRadius.circular(widget.radius),
        image: _image,
      ),
      child: widget.imageUrl == null
          ? Icon(
              widget.fallbackIcon,
              color: AppColors.textMuted,
              size: widget.size * 0.45,
            )
          : null,
    );
  }
}
