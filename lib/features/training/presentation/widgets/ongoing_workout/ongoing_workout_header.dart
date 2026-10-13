import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/app_pressable.dart';
import 'workout_colors.dart';

/// Nagłówek treningu: zwinięcie (trening trwa dalej), nazwa planu z zieloną
/// kropką „na żywo” i czasem, „Zakończ” oraz menu ⋯.
class OngoingWorkoutHeader extends StatelessWidget {
  const OngoingWorkoutHeader({
    super.key,
    required this.planName,
    required this.startedAt,
    required this.onCollapse,
    required this.onMore,
    this.onFinish,
  });

  final String planName;
  final DateTime startedAt;
  final VoidCallback onCollapse;
  final VoidCallback onMore;

  /// `null` wyszarza „Zakończ” (trening bez ćwiczeń).
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Zwiń trening',
            child: AppPressable(
              onTap: onCollapse,
              child: Container(
                key: const Key('collapse-workout-button'),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.tile,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderStrong),
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.iconOnTile,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                _LiveClock(startedAt: startedAt),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _FinishButton(onTap: onFinish),
          const SizedBox(width: 6),
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              key: const Key('workout-more-button'),
              tooltip: 'Więcej: odpoczynek, RIR, tempo, notatka',
              onPressed: onMore,
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.more_vert_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinishButton extends StatelessWidget {
  const _FinishButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: AppPressable(
        onTap: onTap,
        enabled: enabled,
        child: Container(
          key: const Key('finish-workout-button'),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: enabled ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Zakończ',
            style: TextStyle(
              color: enabled
                  ? WorkoutColors.finishText
                  : AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

/// Czas treningu z pulsującą kropką „na żywo” — własny [Timer], żeby sekunda
/// nie przebudowywała całego ekranu. Kropka przygasa co drugie tyknięcie.
class _LiveClock extends StatefulWidget {
  const _LiveClock({required this.startedAt});

  final DateTime startedAt;

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  Timer? _timer;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _elapsed = _now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = _now());
    });
  }

  Duration _now() {
    final elapsed = DateTime.now().toUtc().difference(widget.startedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  @override
  void didUpdateWidget(covariant _LiveClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt) _elapsed = _now();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final dimmed = !reduceMotion && _elapsed.inSeconds.isOdd;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          opacity: dimmed ? 0.35 : 1,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatElapsed(_elapsed),
              style: AppTextStyles.number(size: 20, height: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}

/// `24:13`, a od godziny `1:02:13`.
String formatElapsed(Duration elapsed) {
  final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
  if (elapsed.inHours == 0) return '$minutes:$seconds';
  return '${elapsed.inHours}:$minutes:$seconds';
}
