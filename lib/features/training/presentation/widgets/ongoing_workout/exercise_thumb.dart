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
    this.cardio = false,
  });

  final String? imageUrl;
  final double size;
  final double radius;
  final double opacity;

  /// Bez zdjęcia kardio dostaje turkusowego biegacza zamiast hantla.
  final bool cardio;

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
        color: widget.cardio && widget.imageUrl == null
            ? AppColors.statTeal.withValues(alpha: 0.14)
            : WorkoutColors.field,
        borderRadius: BorderRadius.circular(widget.radius),
        image: _image,
      ),
      child: widget.imageUrl == null
          ? Icon(
              widget.cardio
                  ? Icons.directions_run_rounded
                  : Icons.fitness_center,
              color: widget.cardio ? AppColors.statTeal : AppColors.textMuted,
              size: widget.size * 0.45,
            )
          : null,
    );
  }
}
