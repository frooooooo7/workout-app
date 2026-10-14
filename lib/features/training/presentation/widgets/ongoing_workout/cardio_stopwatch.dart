import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/app_pressable.dart';
import '../../../domain/models/training_session.dart';
import 'workout_accent.dart';
import 'workout_colors.dart';

/// Stoper odcinka kardio. Liczy od znacznika czasu, a nie tyknięć, więc po
/// odblokowaniu ekranu (albo powrocie do aplikacji) pokazuje prawdziwy czas.
///
/// [elapsed] zmienia się raz na sekundę i słuchają go tylko pole czasu
/// i panel stopera; zwykli słuchacze dostają tylko start, pauzę i stop.
class CardioStopwatchController extends ChangeNotifier {
  CardioStopwatchController({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  String? _setId;
  ValueChanged<Duration>? _onSave;
  DateTime? _runningSince;
  Duration _accumulated = Duration.zero;
  Timer? _ticker;

  final ValueNotifier<Duration> elapsed = ValueNotifier(Duration.zero);

  /// Seria, którą mierzy stoper; `null` — stoper wyłączony.
  String? get setId => _setId;

  bool get isActive => _setId != null;

  bool get isRunning => _runningSince != null;

  Duration get current {
    final since = _runningSince;
    if (since == null) return _accumulated;
    return _accumulated + _clock().difference(since);
  }

  /// Startuje pomiar serii [setId] od zera (albo od [from], gdy w polu był
  /// już czas). Poprzedni pomiar przepada. [onSave] dostaje czas po
  /// „Zapisz” ([save]).
  void start(
    String setId, {
    Duration from = Duration.zero,
    ValueChanged<Duration>? onSave,
  }) {
    _setId = setId;
    _onSave = onSave;
    _accumulated = from;
    _runningSince = _clock();
    _startTicker();
    elapsed.value = current;
    notifyListeners();
  }

  void pause() {
    if (!isRunning) return;
    _accumulated = current;
    _runningSince = null;
    _ticker?.cancel();
    elapsed.value = _accumulated;
    notifyListeners();
  }

  void resume() {
    if (!isActive || isRunning) return;
    _runningSince = _clock();
    _startTicker();
    notifyListeners();
  }

  /// „Zapisz”: kończy pomiar i oddaje czas temu, kto go włączył.
  void save() {
    final onSave = _onSave;
    final result = stop();
    onSave?.call(result);
  }

  /// Kończy pomiar i zwraca zmierzony czas.
  Duration stop() {
    final result = current;
    _setId = null;
    _onSave = null;
    _runningSince = null;
    _accumulated = Duration.zero;
    _ticker?.cancel();
    elapsed.value = Duration.zero;
    notifyListeners();
    return result;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => elapsed.value = current,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    elapsed.dispose();
    super.dispose();
  }
}

/// Kolor stopera — turkus odróżnia pomiar od przerwy w kolorze akcentu.
const stopwatchColor = AppColors.statTeal;

/// Panel stopera przy dolnej krawędzi, w miejscu panelu odpoczynku:
/// pierścień z czasem, „Odcinek 1 · cel 15:00”, „Pauza” i „Zapisz”.
class CardioStopwatchPill extends StatelessWidget {
  const CardioStopwatchPill({
    super.key,
    required this.elapsed,
    required this.running,
    required this.caption,
    required this.target,
    required this.onTogglePause,
    required this.onSave,
  });

  final ValueListenable<Duration> elapsed;
  final bool running;

  /// „Odcinek 1 · cel 15:00”.
  final String caption;

  /// Cel odcinka — pierścień pokazuje postęp do niego.
  final Duration? target;
  final VoidCallback onTogglePause;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final accent = WorkoutAccent.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          key: const Key('cardio-stopwatch-pill'),
          constraints: const BoxConstraints(minHeight: 92),
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          decoration: BoxDecoration(
            color: WorkoutColors.restPanel,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: Row(
            children: [
              ValueListenableBuilder<Duration>(
                valueListenable: elapsed,
                builder: (context, value, _) =>
                    _StopwatchRing(elapsed: value, target: target),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      running ? 'Stoper' : 'Stoper · pauza',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: WorkoutColors.textSoft,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'liczy też przy zablokowanym ekranie',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: WorkoutColors.textFaint,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 72,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PillButton(
                      key: const Key('cardio-stopwatch-pause'),
                      label: running ? 'Pauza' : 'Wznów',
                      color: WorkoutColors.restTrack,
                      onTap: onTogglePause,
                    ),
                    const SizedBox(height: 6),
                    _PillButton(
                      key: const Key('cardio-stopwatch-save'),
                      label: 'Zapisz',
                      color: accent.fill,
                      textColor: accent.onFill,
                      onTap: onSave,
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

/// Pierścień 64 px: z celem — postęp do celu, bez — wskazówka sekundowa.
class _StopwatchRing extends StatelessWidget {
  const _StopwatchRing({required this.elapsed, required this.target});

  final Duration elapsed;
  final Duration? target;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final goal = target;
    final fraction = goal != null && goal.inSeconds > 0
        ? (elapsed.inSeconds / goal.inSeconds).clamp(0.0, 1.0)
        : (elapsed.inSeconds % 60) / 60;
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: fraction),
            duration: reduceMotion || fraction == 0
                ? Duration.zero
                : const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (context, value, _) => CustomPaint(
              size: const Size.square(64),
              painter: _RingPainter(fraction: value),
            ),
          ),
          Text(
            formatSetDuration(elapsed.inSeconds),
            key: const ValueKey('cardio-stopwatch-label'),
            style: AppTextStyles.number(size: elapsed.inHours > 0 ? 14 : 18),
          ),
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
    final arcRect = (Offset.zero & size).deflate(stroke / 2 + 1);
    canvas.drawOval(
      arcRect,
      Paint()
        ..color = WorkoutColors.restTrack
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (fraction <= 0) return;
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      Paint()
        ..color = stopwatchColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
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
    this.textColor = AppColors.textPrimary,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color textColor;
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
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
