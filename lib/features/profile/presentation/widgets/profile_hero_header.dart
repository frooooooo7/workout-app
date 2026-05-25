import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/models/user_profile.dart';
import 'profile_bio_section.dart';

class ProfileHeroHeader extends StatelessWidget {
  const ProfileHeroHeader({
    super.key,
    required this.profile,
    required this.onSettingsTap,
    this.showSettings = true,
    this.onBioEditTap,
  });

  final UserProfile profile;
  final VoidCallback onSettingsTap;
  final bool showSettings;
  final VoidCallback? onBioEditTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gradientTop,
            AppColors.gradientHero,
            Color(0xFF1E1240),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            children: [
              if (showSettings)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: onSettingsTap,
                    tooltip: 'Ustawienia profilu',
                    icon: const Icon(Icons.settings_outlined),
                    color: AppColors.textSecondary,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      backgroundColor: AppColors.surface.withValues(alpha: 0.5),
                    ),
                  ),
                )
              else
                const SizedBox(height: 44),
              UserAvatar.fromNames(
                firstName: profile.firstName,
                lastName: profile.lastName,
                imageUrl: profile.avatarUrl,
                size: UserAvatarSize.lg,
              ),
              const SizedBox(height: 14),
              Text(
                profile.fullName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                profile.displayHandle,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ProfileBioSection(
                profile: profile,
                onEditTap: profile.isOwnProfile ? onBioEditTap : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({
    super.key,
    required this.followingCount,
    required this.followersCount,
    required this.workoutsCount,
    required this.onFollowingTap,
    required this.onFollowersTap,
    required this.onWorkoutsTap,
  });

  final int followingCount;
  final int followersCount;
  final int workoutsCount;
  final VoidCallback onFollowingTap;
  final VoidCallback onFollowersTap;
  final VoidCallback onWorkoutsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              label: 'Obserwowani',
              value: followingCount,
              onTap: onFollowingTap,
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
              label: 'Treningi',
              value: workoutsCount,
              onTap: onWorkoutsTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
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
      height: 36,
      color: AppColors.border,
    );
  }
}
