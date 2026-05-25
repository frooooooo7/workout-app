import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/models/following_user.dart';
import 'profile_empty_state.dart';

class FollowingAvatarStrip extends StatelessWidget {
  const FollowingAvatarStrip({
    super.key,
    required this.following,
    this.onSeeAllTap,
    this.onFindPeopleTap,
  });

  final List<FollowingUser> following;
  final VoidCallback? onSeeAllTap;
  final VoidCallback? onFindPeopleTap;

  @override
  Widget build(BuildContext context) {
    if (following.isEmpty) {
      return ProfileEmptyState(
        icon: Icons.people_outline_rounded,
        message: 'Nie obserwujesz jeszcze nikogo.\nZnajdź osoby i śledź ich postępy.',
        actionLabel: 'Znajdź osoby',
        onActionTap: onFindPeopleTap ?? () => context.push('/app/profile/find-people'),
      );
    }

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: following.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          if (index == following.length) {
            return _AddPersonTile(
              onTap: onFindPeopleTap ?? () => context.push('/app/profile/find-people'),
            );
          }
          final user = following[index];
          return _FollowingTile(
            user: user,
            onTap: () => context.push('/app/users/${user.id}'),
          );
        },
      ),
    );
  }
}

class _FollowingTile extends StatelessWidget {
  const _FollowingTile({required this.user, required this.onTap});

  final FollowingUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              UserAvatar.fromNames(
                firstName: user.firstName,
                lastName: user.lastName,
                imageUrl: user.avatarUrl,
                size: UserAvatarSize.md,
              ),
              const SizedBox(height: 6),
              Text(
                user.firstName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPersonTile extends StatelessWidget {
  const _AddPersonTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.person_add_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Szukaj',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.primary,
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
