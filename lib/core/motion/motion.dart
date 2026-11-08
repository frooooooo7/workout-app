import 'package:flutter/widgets.dart';

/// Mocne zejście interfejsu: ruch startuje od razu i miękko ląduje.
/// `cubic-bezier(0.23, 1, 0.32, 1)`.
const Cubic motionEaseOut = Cubic(0.23, 1, 0.32, 1);

/// Para [motionEaseOut] dla `switchOutCurve` i odwracanego kontrolera.
///
/// Wychodzące dziecko leci wartością od 1 do 0. Ease-out nałożony na ten
/// kierunek startuje wolno, więc zejście dostaje odwróconą krzywą.
const Cubic motionEaseOutReverse = Cubic(0.68, 0, 0.77, 0);

const Duration motionChartDuration = Duration(milliseconds: 300);

Duration motionDuration(
  BuildContext context, [
  Duration duration = motionChartDuration,
]) {
  if (MediaQuery.disableAnimationsOf(context)) return Duration.zero;
  return duration;
}

/// Pojawienie się plakietki i ptaszka: skala 0,95 i przezroczystość 0.
class MotionAppear extends StatelessWidget {
  const MotionAppear({
    super.key,
    required this.visible,
    required this.child,
    this.scaleKey,
    this.shown = const Duration(milliseconds: 220),
    this.hidden = const Duration(milliseconds: 140),
  });

  final bool visible;
  final Widget child;

  /// Klucz na [AnimatedScale], tam gdzie testy szukają skali.
  final Key? scaleKey;
  final Duration shown;
  final Duration hidden;

  @override
  Widget build(BuildContext context) {
    final duration = visible ? shown : hidden;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: duration,
        curve: motionEaseOut,
        child: AnimatedScale(
          key: scaleKey,
          scale: visible ? 1 : 0.95,
          duration: duration,
          curve: motionEaseOut,
          child: child,
        ),
      ),
    );
  }
}
