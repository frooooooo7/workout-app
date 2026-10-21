import 'dart:async';

import 'package:flutter/material.dart';

/// Animacja z opóźnieniem startu. Przy włączonym w systemie „ogranicz
/// animacje” od razu pokazuje stan końcowy (`t == 1`).
class ProAnimated extends StatefulWidget {
  const ProAnimated({
    super.key,
    required this.builder,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutCubic,
  });

  final Widget Function(BuildContext context, double t) builder;
  final Duration delay;
  final Duration duration;
  final Curve curve;

  @override
  State<ProAnimated> createState() => _ProAnimatedState();
}

class _ProAnimatedState extends State<ProAnimated>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = 1;
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) =>
          widget.builder(context, widget.curve.transform(_controller.value)),
    );
  }
}

/// Wejście elementu: zanik + przesunięcie o kilkanaście pikseli w górę.
class ProReveal extends StatelessWidget {
  const ProReveal({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return ProAnimated(
      delay: delay,
      builder: (context, t) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: child,
        ),
      ),
    );
  }
}
