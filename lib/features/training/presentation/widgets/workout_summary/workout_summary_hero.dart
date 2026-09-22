import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../session_details/session_details_formatters.dart';

/// Nagłówek podsumowania: znacznik sukcesu, nazwa planu, dzień i zakres
/// godzin. Nie powtarza metryk — te żyją w karcie statystyk poniżej.
class WorkoutSummaryHero extends StatelessWidget {
  const WorkoutSummaryHero({
    super.key,
    required this.planName,
    required this.startedAt,
    this.endedAt,
  });

  final String planName;
  final DateTime startedAt;
  final DateTime? endedAt;

  String get _when {
    final day =
        '${formatWeekdayShort(startedAt)}, '
        '${formatDayNumber(startedAt)} ${formatMonthShort(startedAt)}';
    final end = endedAt;
    final time = end == null
        ? formatClock(startedAt)
        : '${formatClock(startedAt)}–${formatClock(end)}';
    return '$day  ·  $time';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _SuccessBadge(),
        const SizedBox(height: 12),
        const Text(
          'Trening ukończony!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.success,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          planName,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _when,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Zielony okrąg z ptaszkiem — wskakuje z lekkim „odbiciem", a wokół niego
/// rozchodzi się przygaszona poświata, żeby moment ukończenia miał ciężar.
class _SuccessBadge extends StatefulWidget {
  const _SuccessBadge();

  @override
  State<_SuccessBadge> createState() => _SuccessBadgeState();
}

class _SuccessBadgeState extends State<_SuccessBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _halo;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.7, curve: Curves.elasticOut),
    );
    _halo = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 1, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          alignment: Alignment.center,
          children: [
            FadeTransition(
              opacity: Tween<double>(begin: 0.55, end: 0).animate(_halo),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.7, end: 1.3).animate(_halo),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                  ),
                  child: const SizedBox(width: 96, height: 96),
                ),
              ),
            ),
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.success,
                      AppColors.success.withValues(alpha: 0.75),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.35),
                      blurRadius: 24,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
