import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import 'workout_colors.dart';
import 'workout_accent.dart';

/// Duży okrągły przycisk odhaczenia serii. Zrobiona seria jest zielona;
/// odhaczenie „pyka” (1 → 1,15 → 1, easeOutBack), rysuje ptaszek i daje
/// lekką haptykę. Następna seria do zrobienia ([active]) pulsuje obwódką.
class SetCheckButton extends StatefulWidget {
  const SetCheckButton({
    super.key,
    required this.completed,
    required this.active,
    required this.semanticLabel,
    required this.onChanged,
  });

  final bool completed;
  final bool active;

  /// „Seria 3”, „Seria rozgrzewkowa” — opis dla czytnika ekranu.
  final String semanticLabel;
  final ValueChanged<bool> onChanged;

  @override
  State<SetCheckButton> createState() => _SetCheckButtonState();
}

class _SetCheckButtonState extends State<SetCheckButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 1,
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.15,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.15,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 60,
    ),
  ]).animate(_pop);

  bool _subscribed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant SetCheckButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.completed && !oldWidget.completed && !_reduceMotion) {
      _pop.forward(from: 0);
    }
    _syncPulse();
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  bool get _pulsing => widget.active && !widget.completed && !_reduceMotion;

  void _syncPulse() {
    if (_pulsing && !_subscribed) {
      _PulseClock.subscribe();
      _subscribed = true;
    } else if (!_pulsing && _subscribed) {
      _PulseClock.unsubscribe();
      _subscribed = false;
    }
  }

  @override
  void dispose() {
    if (_subscribed) _PulseClock.unsubscribe();
    _pop.dispose();
    super.dispose();
  }

  void _toggle() {
    final next = !widget.completed;
    if (next) unawaited(HapticFeedback.lightImpact());
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final completed = widget.completed;
    final active = widget.active && !completed;
    final size = active ? 38.0 : 36.0;
    final accent = WorkoutAccent.of(context);
    final Color borderColor = active ? accent.strong : AppColors.borderStrong;
    final Color checkColor = completed
        ? WorkoutColors.onSuccess
        : active
        ? accent.strong.withValues(alpha: 0.55)
        : AppColors.textMuted.withValues(alpha: 0.6);

    final circle = AnimatedContainer(
      duration: _reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: completed ? AppColors.success : Colors.transparent,
        border: completed ? null : Border.all(color: borderColor, width: 2),
      ),
      child: AnimatedBuilder(
        animation: _pop,
        builder: (context, _) => CustomPaint(
          painter: _CheckPainter(
            color: checkColor,
            // Ptaszek rysuje się w pierwszych 70% „pyknięcia”.
            progress: completed ? (_pop.value / 0.7).clamp(0.0, 1.0) : 1,
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      toggled: completed,
      label: completed
          ? '${widget.semanticLabel} zrobiona'
          : 'Odhacz: ${widget.semanticLabel}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (_pulsing)
                  ValueListenableBuilder<int>(
                    valueListenable: _PulseClock.beat,
                    builder: (context, beat, _) =>
                        TweenAnimationBuilder<double>(
                          key: ValueKey(beat),
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeOut,
                          builder: (context, t, _) => Container(
                            width: size + 14 * t,
                            height: size + 14 * t,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.strong.withValues(
                                alpha: 0.55 * (1 - t),
                              ),
                            ),
                          ),
                        ),
                  ),
                ScaleTransition(scale: _scale, child: circle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ptaszek (ścieżka z ikony „check”, 24×24) rysowany od lewej do [progress].
class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    const iconSize = 18.0;
    final scale = iconSize / 24;
    final origin = Offset(
      (size.width - iconSize) / 2,
      (size.height - iconSize) / 2,
    );
    Offset p(double x, double y) => origin + Offset(x * scale, y * scale);
    final path = Path()
      ..moveTo(p(4, 12).dx, p(4, 12).dy)
      ..lineTo(p(9, 17).dx, p(9, 17).dy)
      ..lineTo(p(20, 6).dx, p(20, 6).dy);
    final metric = path.computeMetrics().first;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.progress != progress;
}

/// Wspólny rytm pulsu następnej serii: jeden [Timer] dla wszystkich
/// przycisków, więc pulsują razem. Puls to krótka animacja co [period]
/// (a nie pętla bez przerwy) — między pulsami ekran stoi i nie zjada klatek.
abstract final class _PulseClock {
  static const period = Duration(milliseconds: 2200);
  static final ValueNotifier<int> beat = ValueNotifier(0);
  static Timer? _timer;
  static int _subscribers = 0;

  static void subscribe() {
    if (_subscribers++ == 0) {
      _timer = Timer.periodic(period, (_) => beat.value++);
    }
  }

  static void unsubscribe() {
    if (--_subscribers == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }
}
