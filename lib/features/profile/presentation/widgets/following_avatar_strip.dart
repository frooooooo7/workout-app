import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/models/following_user.dart';
import 'profile_empty_state.dart';

/// Poziomy pasek obserwowanych osób z kafelkiem „Szukaj” na końcu.
class FollowingAvatarStrip extends StatelessWidget {
  const FollowingAvatarStrip({
    super.key,
    required this.following,
    this.onFindPeopleTap,
  });

  final List<FollowingUser> following;
  final VoidCallback? onFindPeopleTap;

  @override
  Widget build(BuildContext context) {
    final findPeople =
        onFindPeopleTap ?? () => context.push('/app/profile/find-people');

    if (following.isEmpty) {
      return ProfileEmptyState(
        icon: Icons.people_outline_rounded,
        message:
            'Nie obserwujesz jeszcze nikogo.\nZnajdź osoby i śledź ich postępy.',
        actionLabel: 'Znajdź osoby',
        onActionTap: findPeople,
      );
    }

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
        itemCount: following.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index == following.length) {
            return _AddPersonTile(onTap: findPeople);
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
    return _StripTile(
      onTap: onTap,
      semanticLabel: 'Profil: ${user.firstName} ${user.lastName}',
      label: user.firstName,
      labelColor: AppColors.textSecondary,
      child: UserAvatar.fromNames(
        firstName: user.firstName,
        lastName: user.lastName,
        imageUrl: user.avatarUrl,
        size: UserAvatarSize.md,
      ),
    );
  }
}

class _AddPersonTile extends StatelessWidget {
  const _AddPersonTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _StripTile(
      onTap: onTap,
      semanticLabel: 'Znajdź osoby do obserwowania',
      label: 'Szukaj',
      labelColor: AppColors.primaryVariant,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(
          Icons.person_add_outlined,
          color: AppColors.primaryVariant,
          size: 22,
        ),
      ),
    );
  }
}

class _StripTile extends StatelessWidget {
  const _StripTile({
    required this.onTap,
    required this.semanticLabel,
    required this.label,
    required this.labelColor,
    required this.child,
  });

  final VoidCallback onTap;
  final String semanticLabel;
  final String label;
  final Color labelColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xxs),
              child,
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: labelColor,
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
