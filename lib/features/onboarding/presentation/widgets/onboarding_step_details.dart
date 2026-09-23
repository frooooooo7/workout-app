import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../profile/presentation/widgets/profile_details_fields.dart';
import '../bloc/onboarding_cubit.dart';
import '../bloc/onboarding_state.dart';
import 'onboarding_step_parts.dart';

/// Krok 2: płeć, data urodzenia, wzrost i waga (prywatne).
class OnboardingStepBody extends StatelessWidget {
  const OnboardingStepBody({super.key, required this.state});

  final OnboardingState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();

    return _StepScroll(
      children: [
        const OnboardingStepHeader(
          title: 'O Tobie',
          subtitle: 'Każde pole jest opcjonalne.',
        ),
        const SizedBox(height: AppSpacing.sm),
        const ProfileDetailsPrivacyNote(),
        const SizedBox(height: AppSpacing.xl),
        ProfileBodyFields(
          draft: state.draft,
          enabled: !state.saving,
          onGenderChanged: cubit.genderChanged,
          onBirthDateChanged: cubit.birthDateChanged,
          onHeightChanged: cubit.heightChanged,
          onWeightChanged: cubit.weightChanged,
        ),
      ],
    );
  }
}

/// Krok 3: cel, doświadczenie i liczba treningów w tygodniu (prywatne).
class OnboardingStepGoal extends StatelessWidget {
  const OnboardingStepGoal({super.key, required this.state});

  final OnboardingState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();

    return _StepScroll(
      children: [
        const OnboardingStepHeader(
          title: 'Twój cel',
          subtitle: 'Co chcesz osiągnąć i jak często trenować?',
        ),
        const SizedBox(height: AppSpacing.sm),
        const ProfileDetailsPrivacyNote(),
        const SizedBox(height: AppSpacing.xl),
        ProfileGoalFields(
          draft: state.draft,
          enabled: !state.saving,
          onGoalChanged: cubit.trainingGoalChanged,
          onLevelChanged: cubit.experienceLevelChanged,
          onWeeklyDaysChanged: cubit.weeklyTrainingDaysChanged,
        ),
      ],
    );
  }
}

class _StepScroll extends StatelessWidget {
  const _StepScroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        kOnboardingGutter,
        AppSpacing.sm,
        kOnboardingGutter,
        kOnboardingBottomSpace,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
