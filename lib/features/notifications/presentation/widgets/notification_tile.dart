import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../profile/presentation/bloc/follow_cubit.dart';
import '../../../profile/presentation/bloc/follow_state.dart';
import '../../domain/models/app_notification.dart';
import '../utils/notification_text.dart';

Key notificationTileKey(String id) => ValueKey('notification-$id');
Key notificationFollowBackKey(String userId) =>
    ValueKey('notification-follow-$userId');

/// Wiersz centrum powiadomień: awatar z plakietką rodzaju, opis, czas
/// i kropka nieprzeczytanego (albo „Obserwuj też” przy nowym obserwującym).
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    this.now,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  /// Do testów: stały „teraz” dla względnego czasu.
  final DateTime? now;

  static const _animation = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final unread = !n.read;
    final text = notificationTextParts(n);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: notificationTileKey(n.id),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: _animation,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: unread
                ? AppColors.primary.withValues(alpha: 0.07)
                : AppColors.primary.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _AvatarWithBadge(notification: n),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          for (final part in text)
                            TextSpan(
                              text: part.text,
                              style: part.bold
                                  ? TextStyle(
                                      color:
                                          part.color ?? AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    )
                                  : null,
                            ),
                        ],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.iconOnTile,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatNotificationTime(n.createdAt, now: now),
                      style: const TextStyle(
                        color: AppColors.textLabel,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (n.type == AppNotificationType.follow)
                _FollowBackButton(userId: n.actor.id)
              else
                AnimatedOpacity(
                  opacity: unread ? 1 : 0,
                  duration: _animation,
                  child: Semantics(
                    label: unread ? 'Nieprzeczytane' : null,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarWithBadge extends StatelessWidget {
  const _AvatarWithBadge({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final actor = notification.actor;
    final (icon, color, onColor) = switch (notification.type) {
      AppNotificationType.kudos => (
        Icons.local_fire_department_rounded,
        AppColors.statOrange,
        const Color(0xFF1A0E06),
      ),
      AppNotificationType.follow => (
        Icons.add_rounded,
        AppColors.primaryVariant,
        const Color(0xFF07122B),
      ),
      AppNotificationType.planCopy => (
        Icons.copy_rounded,
        AppColors.statTeal,
        const Color(0xFF062520),
      ),
      AppNotificationType.record => (
        Icons.emoji_events_rounded,
        AppColors.record,
        const Color(0xFF2A1C02),
      ),
    };
    return Stack(
      clipBehavior: Clip.none,
      children: [
        UserAvatar.fromNames(
          firstName: actor.firstName,
          lastName: actor.lastName,
          imageUrl: actor.avatarUrl,
          size: UserAvatarSize.sm,
        ),
        Positioned(
          right: -3,
          bottom: -3,
          child: Container(
            width: 21,
            height: 21,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 2),
            ),
            child: Icon(icon, size: 12, color: onColor),
          ),
        ),
      ],
    );
  }
}

/// „Obserwuj też” / „Obserwujesz” przy nowym obserwującym.
class _FollowBackButton extends StatelessWidget {
  const _FollowBackButton({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FollowCubit, FollowState>(
      buildWhen: (previous, current) =>
          previous.isFollowing(userId) != current.isFollowing(userId) ||
          previous.isPending(userId) != current.isPending(userId),
      builder: (context, state) {
        final following = state.isFollowing(userId);
        final busy = state.isPending(userId);
        return Semantics(
          button: true,
          toggled: following,
          child: GestureDetector(
            key: notificationFollowBackKey(userId),
            behavior: HitTestBehavior.opaque,
            onTap: busy
                ? null
                : () => context.read<FollowCubit>().toggle(userId),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: following ? AppColors.surfaceVariant : AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                following ? 'Obserwujesz' : 'Obserwuj też',
                style: TextStyle(
                  color: following
                      ? AppColors.textSecondary
                      : AppColors.onPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
