import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wejście sekcji podsumowania „z dołu, z wygaszenia" — kolejne elementy
/// startują z lekkim opóźnieniem zależnym od [index], więc ekran buduje się
/// od góry do dołu zamiast pojawić się w całości.
class StaggeredReveal extends StatelessWidget {
  const StaggeredReveal({
    super.key,
    required this.index,
    required this.child,
    this.offset = 18,
  });

  final int index;
  final Widget child;
  final double offset;

  static const _totalDuration = Duration(milliseconds: 900);
  static const _stepFraction = 0.09;
  static const _maxStartFraction = 0.55;

  @override
  Widget build(BuildContext context) {
    final start = math.min(index * _stepFraction, _maxStartFraction);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _totalDuration,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * offset),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
