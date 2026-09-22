import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/models/feed_author.dart';

/// `compact` — szczegóły posta, `large` — karta w feedzie (awatar w
/// gradientowej obwódce).
enum PostAuthorAvatarSize { compact, large }

/// Awatar + imię i nazwisko + znacznik czasu. Tap otwiera profil autora.
class PostAuthorRow extends StatelessWidget {
  const PostAuthorRow({
    super.key,
    required this.author,
    required this.timestamp,
    this.onTap,
    this.trailing,
    this.avatarSize = PostAuthorAvatarSize.compact,
  });

  final FeedAuthor author;
  final String timestamp;
  final VoidCallback? onTap;
  final Widget? trailing;
  final PostAuthorAvatarSize avatarSize;

  @override
  Widget build(BuildContext context) {
    final isLarge = avatarSize == PostAuthorAvatarSize.large;
    final avatar = UserAvatar.fromNames(
      firstName: author.firstName,
      lastName: author.lastName,
      imageUrl: author.avatarUrl,
      size: isLarge ? UserAvatarSize.sm : UserAvatarSize.xs,
    );

    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: onTap != null,
            label: 'Profil: ${author.fullName}',
            excludeSemantics: false,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    if (isLarge) GradientAvatarRing(child: avatar) else avatar,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            author.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: isLarge ? 15 : 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                Icons.fitness_center_rounded,
                                size: 12,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  timestamp,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Obwódka w stylu „stories” wokół awatara. [active] = gradient akcentu,
/// inaczej stonowana ramka.
class GradientAvatarRing extends StatelessWidget {
  const GradientAvatarRing({
    super.key,
    required this.child,
    this.active = true,
    this.radius = 16,
  });

  final Widget child;
  final bool active;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius + 2),
        color: active ? null : AppColors.border,
        gradient: active
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF60A5FA), AppColors.primary, Color(0xFF7C3AED)],
              )
            : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }
}
