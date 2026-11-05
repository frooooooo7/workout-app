import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/pro_trial.dart';
import 'pro_motion.dart';
import 'pro_scaffold.dart';

/// Pasek na ekranie Trening w ostatnim tygodniu miesiąca PRO.
class ProTrialStrip extends StatelessWidget {
  const ProTrialStrip({super.key, required this.trial, required this.onTap});

  final ProTrial trial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        12,
        AppSpacing.pageGutter,
        0,
      ),
      child: ProReveal(
        delay: const Duration(milliseconds: 100),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.borderStrong),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: Image.asset(
                      proBackgroundAsset,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, 0.15),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'PRO · ${proDaysLeftLabel(trial.daysLeft).toUpperCase()}',
                              style: AppTextStyles.number(
                                size: 16,
                                weight: FontWeight.w700,
                                color: AppColors.record,
                              ).copyWith(letterSpacing: 2),
                            ),
                          ),
                          Text(
                            'dzień ${trial.dayNumber} z ${ProTrial.lengthDays}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSubtle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ProAnimated(
                        delay: const Duration(milliseconds: 500),
                        duration: const Duration(milliseconds: 1200),
                        builder: (context, t) => ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: trial.progress * t,
                            minHeight: 6,
                            backgroundColor: AppColors.textPrimary.withValues(
                              alpha: 0.14,
                            ),
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.record,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Zachowaj wykresy, rekordy i plany bez limitu',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: AppSpacing.minTapTarget,
                            child: FilledButton(
                              onPressed: onTap,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.tile,
                                  ),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              child: const Text('Zobacz PRO'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
