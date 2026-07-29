import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/models/recent_activity.dart';
import '../../domain/models/profile_activity.dart';
import '../../domain/models/profile_activity_stat.dart';

class ProfileActivityPostCard extends StatelessWidget {
  const ProfileActivityPostCard({
    super.key,
    required this.activity,
    required this.authorFirstName,
    required this.authorLastName,
    this.authorAvatarUrl,
    this.onTap,
    this.isHighlighted = false,
  });

  final ProfileActivity activity;
  final String authorFirstName;
  final String authorLastName;
  final String? authorAvatarUrl;
  final VoidCallback? onTap;
  final bool isHighlighted;

  static ActivityVisual visualFor(RecentActivityKind kind) =>
      const ActivityVisual(
        icon: Icons.fitness_center_rounded,
        color: Color(0xFF6C8EFF),
        label: 'Trening siłowy',
      );

  @override
  Widget build(BuildContext context) {
    final visual = visualFor(activity.kind);
    final stats = activity.stats.isNotEmpty
        ? activity.stats
        : _fallbackStats(activity);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isHighlighted
                  ? visual.color.withValues(alpha: 0.45)
                  : AppColors.border,
            ),
            boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: visual.color.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    UserAvatar.fromNames(
                      firstName: authorFirstName,
                      lastName: authorLastName,
                      imageUrl: authorAvatarUrl,
                      size: UserAvatarSize.sm,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$authorFirstName $authorLastName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activity.timestampLabel,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: visual.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        visual.label,
                        style: TextStyle(
                          color: visual.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Text(
                  activity.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _ActivityVisualBanner(visual: visual),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    for (var i = 0; i < stats.length; i++) ...[
                      if (i > 0)
                        Container(
                          width: 1,
                          height: 32,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          color: AppColors.border,
                        ),
                      Expanded(child: _StatColumn(stat: stats[i])),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                child: Row(
                  children: [
                    _SocialAction(
                      icon: Icons.thumb_up_outlined,
                      label: _formatCount(activity.kudosCount),
                      onTap: () {},
                    ),
                    const SizedBox(width: 4),
                    _SocialAction(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: _formatCount(activity.commentCount),
                      onTap: () {},
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.share_outlined, size: 20),
                      color: AppColors.textMuted,
                      tooltip: 'Udostępnij',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatCount(int count) {
    if (count == 0) return '';
    return '$count';
  }

  static List<ProfileActivityStat> _fallbackStats(ProfileActivity activity) {
    return [
      ProfileActivityStat(label: 'Czas', value: activity.duration),
      if (activity.detail != null)
        ProfileActivityStat(label: 'Wynik', value: activity.detail!),
    ];
  }
}

class _ActivityVisualBanner extends StatelessWidget {
  const _ActivityVisualBanner({required this.visual});

  final ActivityVisual visual;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  visual.color.withValues(alpha: 0.28),
                  visual.color.withValues(alpha: 0.08),
                  AppColors.surfaceVariant,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: -8,
            child: Icon(
              visual.icon,
              size: 88,
              color: visual.color.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 14,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: visual.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: visual.color.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(visual.icon, color: visual.color, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.stat});

  final ProfileActivityStat stat;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stat.value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          stat.label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SocialAction extends StatelessWidget {
  const _SocialAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ActivityVisual {
  const ActivityVisual({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;
}
