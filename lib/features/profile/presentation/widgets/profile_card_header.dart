import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../feed/presentation/widgets/post_author_row.dart';
import '../../domain/models/user_profile.dart';

/// „Wizytówka” własnego profilu: wyśrodkowany awatar, imię i opis, pod nimi
/// liczby ([ProfileCountersRow]) i przyciski ([ProfileActionButtons]).
/// Profil innej osoby nadal używa `ProfileHeroHeader`.
class ProfileCardHeader extends StatelessWidget {
  const ProfileCardHeader({
    super.key,
    required this.profile,
    required this.counters,
    required this.actions,
    this.onAddBioTap,
  });

  final UserProfile profile;
  final Widget counters;
  final Widget actions;

  /// Własny profil bez opisu — zachęta „Dodaj opis profilu”.
  final VoidCallback? onAddBioTap;

  @override
  Widget build(BuildContext context) {
    final bio = profile.bio?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xs),
          GradientAvatarRing(
            radius: 52,
            child: UserAvatar.fromNames(
              firstName: profile.firstName,
              lastName: profile.lastName,
              imageUrl: profile.avatarUrl,
              size: UserAvatarSize.lg,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            profile.fullName,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              bio,
              maxLines: 3,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ] else if (onAddBioTap != null)
            InkWell(
              key: const ValueKey('profile-add-bio'),
              onTap: onAddBioTap,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: AppColors.primaryVariant,
                    ),
                    SizedBox(width: AppSpacing.xxs),
                    Text(
                      'Dodaj opis profilu',
                      style: TextStyle(
                        color: AppColors.primaryVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          counters,
          const SizedBox(height: AppSpacing.md),
          actions,
        ],
      ),
    );
  }
}

/// Trzy liczby w jednym rzędzie, bez ramki: treningi, obserwujący,
/// obserwowani. Pozycja bez callbacku nie jest klikalna.
class ProfileCountersRow extends StatelessWidget {
  const ProfileCountersRow({
    super.key,
    required this.workoutsCount,
    required this.followersCount,
    required this.followingCount,
    this.onWorkoutsTap,
    this.onFollowersTap,
    this.onFollowingTap,
  });

  final int workoutsCount;
  final int followersCount;
  final int followingCount;
  final VoidCallback? onWorkoutsTap;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Counter(
            key: const ValueKey('profile-counter-workouts'),
            value: workoutsCount,
            label: 'treningów',
            onTap: onWorkoutsTap,
          ),
        ),
        Expanded(
          child: _Counter(
            key: const ValueKey('profile-counter-followers'),
            value: followersCount,
            label: 'obserwujących',
            onTap: onFollowersTap,
          ),
        ),
        Expanded(
          child: _Counter(
            key: const ValueKey('profile-counter-following'),
            value: followingCount,
            label: 'obserwowanych',
            onTap: onFollowingTap,
          ),
        ),
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    super.key,
    required this.value,
    required this.label,
    this.onTap,
  });

  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final formatted = formatCompactCount(value);
    return Semantics(
      button: onTap != null,
      label: '$label: $formatted',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xxs,
              horizontal: 2,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatted,
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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

/// „Edytuj profil” i „Udostępnij profil” obok siebie oraz kwadratowy
/// przycisk „Znajdź osoby”.
class ProfileActionButtons extends StatelessWidget {
  const ProfileActionButtons({
    super.key,
    required this.onEditTap,
    required this.onShareTap,
    required this.onFindPeopleTap,
  });

  final VoidCallback onEditTap;
  final VoidCallback onShareTap;
  final VoidCallback onFindPeopleTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            key: const ValueKey('profile-edit-button'),
            label: 'Edytuj profil',
            onPressed: onEditTap,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ActionButton(
            key: const ValueKey('profile-share-button'),
            label: 'Udostępnij profil',
            onPressed: onShareTap,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          key: const ValueKey('profile-find-people-button'),
          onPressed: onFindPeopleTap,
          tooltip: 'Znajdź osoby',
          icon: const Icon(Icons.person_add_alt_1_outlined, size: 21),
          style: IconButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.border),
            fixedSize: const Size.square(AppSpacing.minTapTarget),
            minimumSize: const Size.square(AppSpacing.minTapTarget),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        minimumSize: const Size(0, AppSpacing.minTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
    );
  }
}
