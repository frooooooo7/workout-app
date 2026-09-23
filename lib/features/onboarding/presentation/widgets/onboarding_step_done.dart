import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../profile/domain/models/profile_details.dart';
import '../../../profile/domain/models/user_profile.dart';
import '../../../profile/presentation/utils/profile_details_labels.dart';

const onboardingStartButtonKey = Key('onboarding-start');

/// Podsumowanie po zakończeniu onboardingu.
class OnboardingStepDone extends StatelessWidget {
  const OnboardingStepDone({
    super.key,
    required this.profile,
    required this.onStart,
  });

  final UserProfile profile;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final summary = _summary(profile.details ?? ProfileDetails.empty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: UserAvatar.fromNames(
            firstName: profile.firstName,
            lastName: profile.lastName,
            imageUrl: profile.avatarUrl,
            size: UserAvatarSize.lg,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Gotowe, ${profile.firstName}!',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          profile.displayHandle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [for (final item in summary) _SummaryChip(label: item)],
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'Wszystko zmienisz później w ustawieniach profilu.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          key: onboardingStartButtonKey,
          onPressed: onStart,
          child: const Text('Zaczynamy'),
        ),
      ],
    );
  }

  static List<String> _summary(ProfileDetails details) {
    final age = details.ageOn(DateTime.now());
    return [
      if (age != null) formatAge(age),
      if (details.heightCm != null) formatHeightCm(details.heightCm!),
      if (details.weightKg != null) formatWeightKg(details.weightKg!),
      if (details.trainingGoal != null) details.trainingGoal!.label,
      if (details.experienceLevel != null) details.experienceLevel!.label,
      if (details.weeklyTrainingDays != null)
        formatWeeklyTrainingDays(details.weeklyTrainingDays!),
    ];
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
