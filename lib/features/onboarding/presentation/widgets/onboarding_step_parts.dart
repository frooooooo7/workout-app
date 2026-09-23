import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../../auth/presentation/widgets/auth_error_banner.dart';
import '../../../auth/presentation/widgets/register_step_progress.dart';

const onboardingNextButtonKey = Key('onboarding-next');
const onboardingSkipButtonKey = Key('onboarding-skip');

/// Poziomy margines treści onboardingu.
const kOnboardingGutter = AppSpacing.lg;

/// Dolny margines przewijanej treści — miejsce pod [OnboardingBottomBar].
const kOnboardingBottomSpace = 128.0;

/// Tytuł kroku i jedno zdanie pod nim.
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
        Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

/// Wstecz (kroki 2–3), postęp i „Pomiń”. Obie boczne strefy mają tę samą
/// szerokość, więc pasek postępu stoi dokładnie na środku.
class OnboardingTopBar extends StatelessWidget {
  const OnboardingTopBar({
    super.key,
    required this.stepIndex,
    required this.onBack,
    required this.onSkip,
  });

  final int stepIndex;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  static const _sideWidth = 76.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: SizedBox(
        height: AppSpacing.minTapTarget,
        child: Row(
          children: [
            SizedBox(
              width: _sideWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: onBack == null
                      ? const SizedBox.shrink()
                      : AppTabHeaderButton.back(onPressed: onBack!),
                ),
              ),
            ),
            Expanded(
              child: Semantics(
                label: 'Krok ${stepIndex + 1} z 3',
                child: RegisterStepProgress(
                  currentStep: stepIndex,
                  stepCount: 3,
                ),
              ),
            ),
            SizedBox(
              width: _sideWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: onSkip == null ? 0 : 1,
                  child: TextButton(
                    key: onboardingSkipButtonKey,
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      minimumSize: const Size(0, AppSpacing.minTapTarget),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Pomiń'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dolny pasek z główną akcją — przyklejony nad klawiaturą, treść
/// przewija się pod nim i łagodnie w nim znika.
class OnboardingBottomBar extends StatelessWidget {
  const OnboardingBottomBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.buttonKey = onboardingNextButtonKey,
    this.saving = false,
    this.error,
    this.showArrow = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Key buttonKey;
  final bool saving;
  final String? error;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background.withValues(alpha: 0),
            AppColors.background,
          ],
          stops: const [0, 0.35],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            kOnboardingGutter,
            AppSpacing.lg,
            kOnboardingGutter,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.bottomCenter,
                child: error == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AuthErrorBanner(message: error!),
                      ),
              ),
              FilledButton(
                key: buttonKey,
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  disabledBackgroundColor: AppColors.surfaceVariant,
                  disabledForegroundColor: AppColors.textMuted,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(label),
                          if (showArrow) ...[
                            const SizedBox(width: AppSpacing.xs),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
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
