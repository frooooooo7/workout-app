import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/app_pressable.dart';
import 'rest_timer_controls.dart';
import 'workout_colors.dart';

/// Pływający panel odpoczynku przy dolnej krawędzi. Wjeżdża od dołu
/// (280 ms, easeOutCubic), gdy [visible], i zjeżdża po końcu przerwy.
class RestTimerDock extends StatelessWidget {
  const RestTimerDock({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 1.4),
        duration: duration,
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: duration,
          curve: Curves.easeOutCubic,
          child: child,
        ),
      ),
    );
  }
}

/// Panel odpoczynku: pierścień odliczający do zera, opis następnej serii,
/// „+15 s” i „Pomiń”. Dotknięcie panelu pozwala wybrać inną długość.
class RestTimerPill extends StatelessWidget {
  const RestTimerPill({
    super.key,
    required this.remaining,
    required this.total,
    required this.caption,
    required this.onExtend,
    required this.onSkip,
    required this.onChangeDuration,
  });

  final ValueListenable<Duration> remaining;
  final Duration total;

  /// „Teraz: seria 3 · 95 kg × 6”.
  final String? caption;
  final VoidCallback onExtend;
  final VoidCallback onSkip;
  final VoidCallback onChangeDuration;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          key: const Key('rest-timer-pill'),
          height: 92,
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          decoration: BoxDecoration(
            color: WorkoutColors.restPanel,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  hint: 'Zmień czas odpoczynku',
                  child: GestureDetector(
                    key: const Key('rest-timer-change-duration'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onChangeDuration,
                    child: Row(
                      children: [
                        ValueListenableBuilder<Duration>(
                          valueListenable: remaining,
                          builder: (context, value, _) =>
                              _RestRing(remaining: value, total: total),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _RestLabels(caption: caption)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 72,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PillButton(
                      key: const Key('rest-timer-extend'),
                      label: '+15 s',
                      color: WorkoutColors.restTrack,
                      onTap: onExtend,
                    ),
                    const SizedBox(height: 6),
                    _PillButton(
                      key: const Key('rest-timer-skip'),
                      label: 'Pomiń',
                      color: AppColors.primary,
                      onTap: onSkip,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestLabels extends StatelessWidget {
  const _RestLabels({required this.caption});

  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Odpoczynek',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 3),
          Text(
            caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: WorkoutColors.textSoft,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 2),
        const Text(
          'dotknij, by zmienić czas',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: WorkoutColors.textFaint,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Pierścień 64 px z czasem w środku. Z sekundy na sekundę przesuwa się
/// płynnie; ostatnie 3 sekundy pulsują.
class _RestRing extends StatelessWidget {
  const _RestRing({required this.remaining, required this.total});

  final Duration remaining;
  final Duration total;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final fraction = total.inMilliseconds == 0
        ? 0.0
        : (remaining.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final seconds = remaining.inSeconds;
    final finalCountdown = seconds > 0 && seconds <= 3 && !reduceMotion;
    final label = Text(
      formatRestRemaining(remaining),
      key: const ValueKey('rest-timer-remaining-label'),
      style: AppTextStyles.number(size: 20),
    );
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: fraction),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (context, value, _) => CustomPaint(
              size: const Size.square(64),
              painter: _RingPainter(fraction: value),
            ),
          ),
          if (finalCountdown)
            TweenAnimationBuilder<double>(
              key: ValueKey(seconds),
              tween: Tween(begin: 1.18, end: 1),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: label,
            )
          else
            label,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction});

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2 + 1);
    final track = Paint()
      ..color = WorkoutColors.restTrack
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawOval(arcRect, track);
    if (fraction <= 0) return;
    final arc = Paint()
      ..color = AppColors.primaryVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, -math.pi / 2, 2 * math.pi * fraction, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: AppPressable(
        onTap: onTap,
        child: Container(
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
