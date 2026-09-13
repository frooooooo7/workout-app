import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../session_details/session_details_formatters.dart';

/// Nagłówek podsumowania: pulsujący znacznik sukcesu, nagłówek i nazwa planu
/// z datą. Nie powtarza metryk — te żyją w siatce poniżej.
class WorkoutSummaryHero extends StatelessWidget {
  const WorkoutSummaryHero({
    super.key,
    required this.planName,
    required this.startedAt,
  });

  final String planName;
  final DateTime startedAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _SuccessBadge(),
        const SizedBox(height: 20),
        const Text(
          'Trening ukończony!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$planName  ·  ${formatDateWithTime(startedAt)}',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            height: 1.35,
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: 132,
          height: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - _halo.value) * 0.55,
                child: Transform.scale(
                  scale: 0.7 + _halo.value * 0.6,
                  child: Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              Transform.scale(
                scale: _scale.value,
                child: Container(
                  width: 88,
                  height: 88,
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
                        blurRadius: 32,
                        spreadRadius: 2,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 46,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
