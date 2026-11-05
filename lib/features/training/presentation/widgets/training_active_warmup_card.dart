import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../domain/models/warmup.dart';

/// Pasek trwającej (schowanej) rozgrzewki nad kartą planu — stuknięcie wraca
/// do panelu ze stoperem.
class TrainingActiveWarmupCard extends StatefulWidget {
  const TrainingActiveWarmupCard({
    super.key,
    required this.warmup,
    required this.onResume,
    this.clock,
  });

  final WarmupInProgress warmup;
  final VoidCallback onResume;
  final DateTime Function()? clock;

  @override
  State<TrainingActiveWarmupCard> createState() =>
      _TrainingActiveWarmupCardState();
}

class _TrainingActiveWarmupCardState extends State<TrainingActiveWarmupCard> {
  Timer? _ticker;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warmup = widget.warmup;
    final now = _now();
    final elapsed = warmup.elapsed(now);
    final reached = warmup.isGoalReached(now);
    final color = reached ? AppColors.success : AppColors.primaryVariant;
    final progress = warmup.targetDuration.inMilliseconds == 0
        ? 1.0
        : (elapsed.inMilliseconds / warmup.targetDuration.inMilliseconds).clamp(
            0.0,
            1.0,
          );
    final clock = formatWarmupClock(elapsed);

    return Semantics(
      button: true,
      label:
          'Trwa rozgrzewka przed ${warmup.target.name}, $clock. '
          'Wróć do rozgrzewki',
      excludeSemantics: true,
      child: AppPressable(
        key: const ValueKey('active-warmup-resume'),
        pressedScale: 0.98,
        onTap: widget.onResume,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3.5,
                      color: color,
                      backgroundColor: AppColors.chartTrack,
                    ),
                    Icon(Icons.directions_run_rounded, color: color, size: 20),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trwa rozgrzewka · $clock',
                      key: const ValueKey('active-warmup-clock'),
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      warmup.target.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Wróć',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
