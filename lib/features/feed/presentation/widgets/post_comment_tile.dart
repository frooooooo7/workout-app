import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/models/post_comment.dart';
import '../utils/feed_formatters.dart';

class PostCommentTile extends StatelessWidget {
  const PostCommentTile({
    super.key,
    required this.comment,
    this.onAuthorTap,
    this.onDelete,
  });

  final PostComment comment;
  final VoidCallback? onAuthorTap;

  /// `null`, gdy komentarza nie można usunąć.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final author = comment.author;

    return Opacity(
      opacity: comment.isPending ? 0.6 : 1,
      child: InkWell(
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onAuthorTap,
                child: UserAvatar.fromNames(
                  firstName: author.firstName,
                  lastName: author.lastName,
                  imageUrl: author.avatarUrl,
                  size: UserAvatarSize.xs,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onTap: onAuthorTap,
                            child: Text(
                              author.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          comment.isPending
                              ? 'Wysyłanie…'
                              : formatFeedTimestamp(comment.createdAt),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      comment.body,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Opcje komentarza',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
