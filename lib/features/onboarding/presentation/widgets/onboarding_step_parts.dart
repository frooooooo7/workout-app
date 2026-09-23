import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/widgets/auth_error_banner.dart';

const onboardingNextButtonKey = Key('onboarding-next');
const onboardingSkipButtonKey = Key('onboarding-skip');

class OnboardingStepHeader extends StatelessWidget {
  const OnboardingStepHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Błąd zapisu, „Dalej” (z postępem) i „Pomiń”.
class OnboardingStepActions extends StatelessWidget {
  const OnboardingStepActions({
    super.key,
    required this.nextLabel,
    required this.onNext,
    required this.onSkip,
    required this.saving,
    this.error,
  });

  final String nextLabel;
  final VoidCallback? onNext;
  final VoidCallback? onSkip;
  final bool saving;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (error != null) ...[
          AuthErrorBanner(message: error!),
          const SizedBox(height: 16),
        ],
        ElevatedButton(
          key: onboardingNextButtonKey,
          onPressed: onNext,
          child: saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                )
              : Text(nextLabel),
        ),
        const SizedBox(height: 4),
        TextButton(
          key: onboardingSkipButtonKey,
          onPressed: onSkip,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            minimumSize: const Size.fromHeight(44),
          ),
          child: const Text('Pomiń'),
        ),
      ],
    );
  }
}
