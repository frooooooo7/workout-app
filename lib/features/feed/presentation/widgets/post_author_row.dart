import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/models/feed_author.dart';

/// Awatar + imię i nazwisko + znacznik czasu. Tap otwiera profil autora.
class PostAuthorRow extends StatelessWidget {
  const PostAuthorRow({
    super.key,
    required this.author,
    required this.timestamp,
    this.onTap,
    this.trailing,
  });

  final FeedAuthor author;
  final String timestamp;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
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
                    UserAvatar.fromNames(
                      firstName: author.firstName,
                      lastName: author.lastName,
                      imageUrl: author.avatarUrl,
                      size: UserAvatarSize.xs,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            author.fullName,
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
                            timestamp,
                            maxLines: 1,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
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
