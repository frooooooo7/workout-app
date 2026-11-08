import 'package:flutter/material.dart';

import '../../../../core/launch/app_launch_scope.dart';

/// Łagodne wejście karty ekranu startowego: pojawia się i wysuwa o 12 px,
/// z opóźnieniem rosnącym z [index]. Raz, przy pierwszym pokazaniu;
/// przy „Ogranicz ruch” karta jest od razu na miejscu. Przy starcie
/// aplikacji czeka, aż ekran ładowania zacznie znikać, żeby wejście nie
/// odegrało się niewidocznie pod nim.
class TrainingStaggeredEntrance extends StatefulWidget {
  const TrainingStaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.offset = 12,
  });

  final int index;
  final Widget child;

  /// O ile pikseli karta wysuwa się z dołu (0 — tylko pojawia się).
  final double offset;

  static const _duration = Duration(milliseconds: 280);
  static const _step = Duration(milliseconds: 60);

  @override
  State<TrainingStaggeredEntrance> createState() =>
      _TrainingStaggeredEntranceState();
}

class _TrainingStaggeredEntranceState extends State<TrainingStaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _delay + TrainingStaggeredEntrance._duration,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    // Opóźnienie jako pusty początek przedziału — jeden kontroler, bez timerów.
    curve: Interval(
      _delay.inMilliseconds / _controller.duration!.inMilliseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  Duration get _delay => TrainingStaggeredEntrance._step * widget.index;

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.value = 1;
      return;
    }
    final launch = AppLaunchScope.maybeOf(context);
    if (launch == null || launch.revealed) {
      _controller.forward();
    } else {
      launch.whenRevealed.then((_) {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _progress.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _progress.value)),
          child: child,
        ),
      ),
    );
  }
}
