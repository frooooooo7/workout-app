import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../../profile/presentation/widgets/avatar_picker_field.dart';
import '../bloc/onboarding_cubit.dart';
import '../bloc/onboarding_state.dart';
import '../widgets/onboarding_step_details.dart';
import '../widgets/onboarding_step_done.dart';
import '../widgets/onboarding_step_parts.dart';
import '../widgets/onboarding_step_profile.dart';

const onboardingDeferButtonKey = Key('onboarding-defer');

/// Onboarding po rejestracji (wymaga [OnboardingCubit] w kontekście).
/// [onFinish] — „Zaczynamy” po zakończeniu; [onDefer] — „Dokończ później”,
/// gdy profilu nie da się wczytać (np. brak sieci).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onFinish,
    required this.onDefer,
  });

  final VoidCallback onFinish;
  final VoidCallback onDefer;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  /// Kierunek ostatniej zmiany kroku — nowy krok wjeżdża z tej strony.
  var _shownStep = OnboardingStep.profile;
  var _forward = true;

  Future<void> _pickAvatar() async {
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
        if (state.step != _shownStep) {
          _forward = state.step.index > _shownStep.index;
          _shownStep = state.step;
        }
        final loaded = state.profile != null;
        final done = state.step == OnboardingStep.done;

        return PopScope(
          // Konto już istnieje — systemowe „wstecz” cofa tylko między
          // krokami; na pierwszym (i po zakończeniu) zamyka aplikację.
          canPop: !state.canGoBack,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) cubit.back();
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: AppTabBackground(
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    OnboardingTopBar(
                      stepIndex: math.min(state.step.index, 2),
                      onBack: state.canGoBack ? cubit.back : null,
                      onSkip: loaded && !done && !state.saving
                          ? cubit.skip
                          : null,
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(child: _buildContent(state)),
                          if (loaded)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: done
                                  ? OnboardingBottomBar(
                                      buttonKey: onboardingStartButtonKey,
                                      label: 'Zaczynamy',
                                      onPressed: widget.onFinish,
                                    )
                                  : OnboardingBottomBar(
                                      label: state.step == OnboardingStep.goal
                                          ? 'Zakończ'
                                          : 'Dalej',
                                      onPressed: state.canContinue
                                          ? cubit.next
                                          : null,
                                      saving: state.saving,
                                      error: state.error,
                                    ),
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
      },
    );
  }

  Widget _buildContent(OnboardingState state) {
    final profile = state.profile;
    if (profile == null) {
      if (state.loadError != null) {
        return _LoadError(
          message: state.loadError!,
          onRetry: context.read<OnboardingCubit>().load,
          onDefer: widget.onDefer,
        );
      }
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final step = switch (state.step) {
      OnboardingStep.profile => OnboardingStepProfile(
        state: state,
        onPickAvatar: _pickAvatar,
      ),
      OnboardingStep.body => OnboardingStepBody(state: state),
      OnboardingStep.goal => OnboardingStepGoal(state: state),
      OnboardingStep.done => OnboardingStepDone(profile: profile),
    };

    final currentKey = ValueKey(state.step);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) =>
          Stack(children: [...previous, ?current]),
      // Wspólna oś: nowy krok wjeżdża z kierunku ruchu, stary odjeżdża.
      transitionBuilder: (child, animation) {
        final incoming = child.key == currentKey;
        final dx = incoming == _forward ? 0.08 : -0.08;
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(dx, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: currentKey, child: step),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({
    required this.message,
    required this.onRetry,
    required this.onDefer,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDefer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(kOnboardingGutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: AppColors.textSecondary,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Spróbuj ponownie'),
            ),
            const SizedBox(height: AppSpacing.xxs),
            TextButton(
              key: onboardingDeferButtonKey,
              onPressed: onDefer,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                minimumSize: const Size.fromHeight(AppSpacing.minTapTarget),
              ),
              child: const Text('Dokończ później'),
            ),
          ],
        ),
      ),
    );
  }
}
