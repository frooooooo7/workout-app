import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/units/weight_unit.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../domain/services/body_weight_trend.dart';
import '../utils/body_weight_format.dart';
import '../utils/profile_details_labels.dart';

const bodyWeightGoalCardKey = Key('body-weight-goal-card');
const bodyWeightGoalCtaKey = Key('body-weight-goal-cta');

/// Cel masy ciała: wartość, ile zostało i pasek postępu od startu do celu.
/// Dotknięcie otwiera edycję celu.
class BodyWeightGoalCard extends StatelessWidget {
  const BodyWeightGoalCard({
    super.key,
    required this.progress,
    required this.onTap,
  });

  final BodyWeightGoalProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.fraction * 100).round();
    return AppPressable(
      key: bodyWeightGoalCardKey,
      pressedScale: 0.98,
      onTap: onTap,
      child: Semantics(
        button: true,
        hint: 'Zmień cel',
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: _cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.track_changes_rounded,
                    size: 16,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Cel: ${formatWeightKg(progress.goalKg)}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _Remaining(progress: progress),
                ],
              ),
              const SizedBox(height: 10),
              Semantics(
                label: 'Postęp do celu',
                value: '$percent%',
                child: _ProgressBar(fraction: progress.fraction),
              ),
              const SizedBox(height: 6),
              DefaultTextStyle(
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('start ${formatWeightValue(progress.startKg)}'),
                      Text('$percent%'),
                      Text('cel ${formatWeightValue(progress.goalKg)}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Zachęta dla osób bez celu — lekka, żeby nie dominowała nad wagą.
class BodyWeightGoalCta extends StatelessWidget {
  const BodyWeightGoalCta({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      key: bodyWeightGoalCtaKey,
      pressedScale: 0.98,
      onTap: onTap,
      child: Semantics(
        button: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: _cardDecoration,
          child: const Row(
            children: [
              Icon(
                Icons.track_changes_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cel wagi',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Postęp i prognoza, kiedy go osiągniesz.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.xs),
              Text(
                'Ustaw cel',
                style: TextStyle(
                  color: AppColors.primaryVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _cardDecoration = BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: AppColors.border),
);

class _Remaining extends StatelessWidget {
  const _Remaining({required this.progress});

  final BodyWeightGoalProgress progress;

  @override
  Widget build(BuildContext context) {
    if (progress.reached) {
      return const Text(
        'Cel osiągnięty',
        style: TextStyle(
          color: AppColors.success,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
      );
    }
    return Text.rich(
      TextSpan(
        text: 'zostało ',
        children: [
          TextSpan(
            text:
                '${formatBodyWeightDelta(progress.remainingKg)} '
                '${WeightUnits.current.label}',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ],
      ),
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Pasek 8 px z kółkiem na końcu wypełnienia; wypełnia się przy pokazaniu.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});

  final double fraction;

  static const _thumb = 14.0;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return SizedBox(
      height: _thumb,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 600),
            curve: Curves.easeOutExpo,
            builder: (context, value, _) {
              final x = width * value;
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.chartTrack,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    width: x,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Positioned(
                    left: (x - _thumb / 2).clamp(0, width - _thumb),
                    child: Container(
                      width: _thumb,
                      height: _thumb,
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.success, width: 3),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
