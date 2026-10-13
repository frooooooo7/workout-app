import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_pressable.dart';

/// Pasek trwającego treningu nad kartą planu — stuknięcie wraca do sesji.
class TrainingActiveSessionCard extends StatelessWidget {
  const TrainingActiveSessionCard({
    super.key,
    required this.planName,
    required this.onResume,
  });

  final String planName;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Trwa trening: $planName. Wróć do treningu',
      excludeSemantics: true,
      child: AppPressable(
        key: const ValueKey('active-session-resume'),
        pressedScale: 0.98,
        onTap: onResume,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trwa trening',
                      style: TextStyle(
                        color: AppColors.primaryVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      planName,
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
              const Text(
                'Wróć',
                style: TextStyle(
                  color: AppColors.primaryVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.primaryVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
