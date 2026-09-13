import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wejście sekcji podsumowania „z dołu, z wygaszenia" — kolejne elementy
/// startują z lekkim opóźnieniem zależnym od [index], więc ekran buduje się
/// od góry do dołu zamiast pojawić się w całości.
class StaggeredReveal extends StatefulWidget {
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
  State<StaggeredReveal> createState() => _StaggeredRevealState();
}

class _StaggeredRevealState extends State<StaggeredReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final start = math.min(
      widget.index * StaggeredReveal._stepFraction,
      StaggeredReveal._maxStartFraction,
    );
    _controller = AnimationController(
      vsync: this,
      duration: StaggeredReveal._totalDuration,
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
    );
    _fade = curve;
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offset / 400),
      end: Offset.zero,
    ).animate(curve);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
