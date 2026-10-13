import 'package:flutter/material.dart';

/// Łagodne wejście karty ekranu startowego: pojawia się i wysuwa o 12 px,
/// z opóźnieniem rosnącym z [index]. Raz, przy pierwszym pokazaniu;
/// przy „Ogranicz ruch” karta jest od razu na miejscu.
class TrainingStaggeredEntrance extends StatefulWidget {
  const TrainingStaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  static const _duration = Duration(milliseconds: 380);
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
    } else {
      _controller.forward();
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
          offset: Offset(0, 12 * (1 - _progress.value)),
          child: child,
        ),
      ),
    );
  }
}
