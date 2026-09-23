import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/widgets/auth_card.dart';
import '../../../auth/presentation/widgets/auth_form_top_bar.dart';
import '../../../auth/presentation/widgets/auth_glow_background.dart';
import '../../../auth/presentation/widgets/register_step_progress.dart';
import '../../../profile/presentation/widgets/avatar_picker_field.dart';
import '../bloc/onboarding_cubit.dart';
import '../bloc/onboarding_state.dart';
import '../widgets/onboarding_step_details.dart';
import '../widgets/onboarding_step_done.dart';
import '../widgets/onboarding_step_profile.dart';

const onboardingDeferButtonKey = Key('onboarding-defer');

/// Onboarding po rejestracji (wymaga [OnboardingCubit] w kontekście).
/// [onFinish] — „Zaczynamy” po zakończeniu; [onDefer] — „Dokończ później”,
/// gdy profilu nie da się wczytać (np. brak sieci).
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    super.key,
    required this.onFinish,
    required this.onDefer,
  });

  final VoidCallback onFinish;
  final VoidCallback onDefer;

  Future<void> _pickAvatar(BuildContext context) async {
    final cubit = context.read<OnboardingCubit>();
    final picked = await pickAvatarImage(context);
    if (picked == null) return;
    cubit.avatarPicked(picked.bytes, picked.filename);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final cubit = context.read<OnboardingCubit>();
        return PopScope(
          // Konto już istnieje — systemowe „wstecz” cofa tylko między
          // krokami; na pierwszym (i po zakończeniu) zamyka aplikację.
          canPop: !state.canGoBack,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) cubit.back();
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: AuthGlowBackground(
              child: SafeArea(
                child: Column(
                  children: [
                    AuthFormTopBar(
                      onBack: state.canGoBack ? cubit.back : null,
                      child: RegisterStepProgress(
                        currentStep: math.min(state.step.index, 2),
                        stepCount: 3,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                          child: AuthCard(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: _buildContent(context, state),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, OnboardingState state) {
    final profile = state.profile;
    if (profile == null) {
      if (state.loadError != null) {
        return _LoadError(
          key: const ValueKey('onboarding-load-error'),
          message: state.loadError!,
          onRetry: context.read<OnboardingCubit>().load,
          onDefer: onDefer,
        );
      }
      return const Padding(
        key: ValueKey('onboarding-loading'),
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return switch (state.step) {
      OnboardingStep.profile => OnboardingStepProfile(
          key: const ValueKey('onboarding-step-profile'),
          state: state,
          onPickAvatar: () => _pickAvatar(context),
        ),
      OnboardingStep.body => OnboardingStepBody(
          key: const ValueKey('onboarding-step-body'),
          state: state,
        ),
      OnboardingStep.goal => OnboardingStepGoal(
          key: const ValueKey('onboarding-step-goal'),
          state: state,
        ),
      OnboardingStep.done => OnboardingStepDone(
          key: const ValueKey('onboarding-step-done'),
          profile: profile,
          onStart: onFinish,
        ),
    };
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onDefer,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDefer;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.cloud_off_rounded,
          color: AppColors.textMuted,
          size: 40,
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: onRetry,
          child: const Text('Spróbuj ponownie'),
        ),
        const SizedBox(height: 4),
        TextButton(
          key: onboardingDeferButtonKey,
          onPressed: onDefer,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            minimumSize: const Size.fromHeight(44),
          ),
          child: const Text('Dokończ później'),
        ),
      ],
    );
  }
}
