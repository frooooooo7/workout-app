import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../feed/presentation/widgets/post_author_row.dart';
import '../../domain/models/user_profile.dart';
import 'follow_button.dart';

/// Nagłówek profilu: awatar, imię, @handle, opis, główna akcja i liczniki.
/// Pasek z tytułem ([AppTabHeader]) jest przypięty nad listą w ekranie,
/// a tło (poświatę) daje [AppTabBackground].
class ProfileHeroHeader extends StatelessWidget {
  const ProfileHeroHeader({
    super.key,
    required this.profile,
    this.primaryAction,
    this.stats,
    this.followsYou = false,
    this.onAddBioTap,
  });

  final UserProfile profile;

  /// „Edytuj profil” albo „Obserwuj” — na pełną szerokość.
  final Widget? primaryAction;

  /// Rząd liczników pod akcją ([ProfileStatsRow]).
  final Widget? stats;

  /// Znacznik „Obserwuje Cię” obok @handle.
  final bool followsYou;

  /// Własny profil bez opisu — zachęta „Dodaj opis profilu”.
  final VoidCallback? onAddBioTap;

  @override
  Widget build(BuildContext context) {
    final bio = profile.bio?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageGutter,
            ),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xs),
                GradientAvatarRing(
                  radius: 46,
                  child: UserAvatar.fromNames(
                    firstName: profile.firstName,
                    lastName: profile.lastName,
                    imageUrl: profile.avatarUrl,
                    size: UserAvatarSize.lg,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  profile.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    Text(
                      profile.displayHandle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (followsYou) const FollowsYouChip(),
                  ],
                ),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(
                      bio,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ),
                ] else if (onAddBioTap != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  TextButton.icon(
                    key: const ValueKey('profile-add-bio'),
                    onPressed: onAddBioTap,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Dodaj opis profilu'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryVariant,
                      minimumSize: const Size(0, AppSpacing.minTapTarget),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (primaryAction != null) ...[
                  SizedBox(
                    height: bio.isEmpty && onAddBioTap != null
                        ? AppSpacing.xs
                        : AppSpacing.lg,
                  ),
                  SizedBox(width: double.infinity, child: primaryAction),
                ],
                if (stats != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  stats!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Przycisk „Edytuj profil” w nagłówku własnego profilu.
class ProfileEditButton extends StatelessWidget {
  const ProfileEditButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const ValueKey('profile-edit-button'),
      onPressed: onPressed,
      icon: const Icon(Icons.edit_outlined, size: 18),
      label: const Text('Edytuj profil'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        minimumSize: const Size.fromHeight(AppSpacing.minTapTarget),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Liczniki profilu. Pozycja bez [onTap] nie jest klikalna.
class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({
    super.key,
    required this.followingCount,
    required this.followersCount,
    required this.workoutsCount,
    this.onFollowingTap,
    this.onFollowersTap,
    this.onWorkoutsTap,
  });

  final int followingCount;
  final int followersCount;
  final int workoutsCount;
  final VoidCallback? onFollowingTap;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onWorkoutsTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _StatItem(
                label: 'Treningi',
                value: workoutsCount,
                onTap: onWorkoutsTap,
              ),
            ),
            const _VerticalDivider(),
            Expanded(
              child: _StatItem(
                label: 'Obserwujący',
                value: followersCount,
                onTap: onFollowersTap,
              ),
            ),
            const _VerticalDivider(),
            Expanded(
              child: _StatItem(
                label: 'Obserwowani',
                value: followingCount,
                onTap: onFollowingTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value, this.onTap});

  final String label;
  final int value;
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
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.xxs,
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
                    fontSize: 18,
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
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      color: AppColors.border.withValues(alpha: 0.7),
    );
  }
}
