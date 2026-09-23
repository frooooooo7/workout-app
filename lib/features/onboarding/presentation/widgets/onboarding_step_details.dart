import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    final enabled = !state.saving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const OnboardingStepHeader(
          title: 'O Tobie',
          subtitle: 'Krok 2 z 3 — pomoże dopasować treningi do Ciebie.',
        ),
        const SizedBox(height: 12),
        const ProfileDetailsPrivacyNote(),
        const SizedBox(height: 24),
        ProfileBodyFields(
          draft: state.draft,
          enabled: enabled,
          onGenderChanged: cubit.genderChanged,
          onBirthDateChanged: cubit.birthDateChanged,
          onHeightChanged: cubit.heightChanged,
          onWeightChanged: cubit.weightChanged,
        ),
        const SizedBox(height: 24),
        OnboardingStepActions(
          nextLabel: 'Dalej',
          onNext: state.canContinue ? cubit.next : null,
          onSkip: enabled ? cubit.skip : null,
          saving: state.saving,
          error: state.error,
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
    final enabled = !state.saving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const OnboardingStepHeader(
          title: 'Twój cel',
          subtitle: 'Krok 3 z 3 — co chcesz osiągnąć?',
        ),
        const SizedBox(height: 12),
        const ProfileDetailsPrivacyNote(),
        const SizedBox(height: 24),
        ProfileGoalFields(
          draft: state.draft,
          enabled: enabled,
          onGoalChanged: cubit.trainingGoalChanged,
          onLevelChanged: cubit.experienceLevelChanged,
          onWeeklyDaysChanged: cubit.weeklyTrainingDaysChanged,
        ),
        const SizedBox(height: 24),
        OnboardingStepActions(
          nextLabel: 'Zakończ',
          onNext: state.canContinue ? cubit.next : null,
          onSkip: enabled ? cubit.skip : null,
          saving: state.saving,
          error: state.error,
        ),
      ],
    );
  }
}
