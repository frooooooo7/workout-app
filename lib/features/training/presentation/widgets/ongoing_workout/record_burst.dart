import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import 'workout_colors.dart';

/// Co pokazać na karcie „Nowy rekord!”.
class RecordBurstData {
  const RecordBurstData({
    required this.id,
    required this.exerciseName,
    required this.result,
    this.improvement,
  });

  /// Seria, która pobiła rekord — nowa seria to nowa karta.
  final String id;
  final String exerciseName;

  /// `95 kg × 6`.
  final String result;

  /// `+2,5 kg`.
  final String? improvement;
}

/// Karta „Nowy rekord!” tuż po odhaczeniu serii, nie dopiero w
/// podsumowaniu: wskakuje sprężyście (450 ms), przechodzi po niej jeden
/// połysk, rozpryskuje się konfetti, a po chwili sama znika ([onDone]).
class RecordBurst extends StatefulWidget {
  const RecordBurst({super.key, required this.data, required this.onDone});

  final RecordBurstData data;
  final VoidCallback onDone;

  @override
  State<RecordBurst> createState() => _RecordBurstState();
}

class _RecordBurstState extends State<RecordBurst>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 3200);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _total,
  );

  /// Odcinki osi czasu (ułamki [_total]).
  late final _enter = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.16, curve: ElasticOutCurve(0.7)),
  );
  late final _shine = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.1, 0.35, curve: Curves.easeInOut),
  );
  late final _confetti = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.3, curve: Curves.easeOut),
  );
  late final _exit = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.88, 1, curve: Curves.easeIn),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final card = _RecordCard(data: widget.data, shine: _shine);
    return Semantics(
      liveRegion: true,
      label:
          'Nowy rekord! ${widget.data.exerciseName} ${widget.data.result}'
          '${widget.data.improvement == null ? '' : ' ${widget.data.improvement}'}',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final opacity = 1 - _exit.value;
          if (reduceMotion) return Opacity(opacity: opacity, child: child);
          return Opacity(
            opacity: opacity,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ConfettiPainter(progress: _confetti.value),
                  ),
                ),
                Transform.scale(scale: 0.6 + 0.4 * _enter.value, child: child),
              ],
            ),
          );
        },
        child: card,
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.data, required this.shine});

  final RecordBurstData data;
  final Animation<double> shine;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('record-burst-card'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [WorkoutColors.recordCardStart, WorkoutColors.recordCardEnd],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.record.withValues(alpha: 0.45)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.record.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.emoji_events_outlined,
                    color: AppColors.record,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Nowy rekord!',
                        style: TextStyle(
                          color: AppColors.record,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: '${data.exerciseName} '),
                            TextSpan(text: data.result),
                            if (data.improvement != null)
                              TextSpan(
                                text: '  ${data.improvement}',
                                style: const TextStyle(
                                  color: AppColors.success,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Jeden przebieg połysku po karcie.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: shine,
                builder: (context, _) {
                  if (shine.value <= 0 || shine.value >= 1) {
                    return const SizedBox.shrink();
                  }
                  return FractionalTranslation(
                    translation: Offset(-0.3 + 1.6 * shine.value, 0),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              WorkoutColors.recordText.withValues(alpha: 0),
                              WorkoutColors.recordText.withValues(alpha: 0.35),
                              WorkoutColors.recordText.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kilkanaście kolorowych drobin rozlatujących się spod karty.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress});

  final double progress;

  static const _colors = [
    AppColors.record,
    AppColors.success,
    AppColors.planPush,
    AppColors.primaryVariant,
  ];
  static const _count = 14;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = size.center(Offset.zero);
    final paint = Paint();
    for (var i = 0; i < _count; i++) {
      final angle = (i / _count) * 2 * math.pi + i * 0.37;
      final distance = (size.width * 0.35 + (i % 3) * 18) * progress;
      final offset =
          center +
          Offset(math.cos(angle) * distance, math.sin(angle) * distance * 0.6);
      paint.color = _colors[i % _colors.length].withValues(alpha: 1 - progress);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: offset, width: 7, height: i.isEven ? 7 : 10),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
