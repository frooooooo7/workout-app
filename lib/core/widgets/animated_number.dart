import 'package:flutter/material.dart';

/// Liczba, która przy pierwszym pokazaniu i każdej zmianie „dolicza się” do
/// nowej wartości (sumy objętości, masa ciała, liczniki serii).
///
/// [format] zamienia bieżącą wartość pośrednią na tekst, np.
/// `formatDisplayNumber`. Styl powinien mieć cyfry tabelaryczne, żeby tekst
/// nie skakał w trakcie animacji.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.easeOutCubic,
    this.from = 0,
  });

  final double value;
  final String Function(double value) format;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  /// Wartość startowa przy pierwszym pokazaniu.
  final double from;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      label: format(value),
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: from, end: value),
        duration: reduceMotion ? Duration.zero : duration,
        curve: curve,
        builder: (context, current, _) => Text(format(current), style: style),
      ),
    );
  }
}
