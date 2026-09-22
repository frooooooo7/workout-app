import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Pulsujące przyciemnienie szkieletu na czas pierwszego wczytania.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child, this.label});

  final Widget child;

  /// Opis dla czytnika ekranu, np. „Wczytywanie profilu”.
  final String? label;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.55,
    upperBound: 1,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      child: FadeTransition(opacity: _controller, child: widget.child),
    );
  }
}

/// Prostokąt-zaślepka w kolorze [AppColors.surfaceVariant].
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    this.width,
    required this.height,
    this.radius = 6,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
