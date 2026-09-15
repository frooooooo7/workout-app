import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/feed_post.dart';
import '../utils/feed_formatters.dart';
import 'stacked_avatars.dart';

/// Stopka posta: podsumowanie (awatary kudosów, liczniki) i akcje
/// „Kudos” / „Komentarz”. Własny post nie ma przycisku kudosa.
class PostSocialBar extends StatelessWidget {
  const PostSocialBar({
    super.key,
    required this.post,
    this.onKudosTap,
    this.onKudosListTap,
    this.onCommentTap,
  });

  final FeedPost post;
  final VoidCallback? onKudosTap;
  final VoidCallback? onKudosListTap;
  final VoidCallback? onCommentTap;

  @override
  Widget build(BuildContext context) {
    final hasSummary = post.kudosCount > 0 || post.commentCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasSummary)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PostSocialSummary(
              post: post,
              onKudosListTap: onKudosListTap,
              onCommentsTap: onCommentTap,
            ),
          ),
        Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
        const SizedBox(height: 4),
        Row(
          children: [
            if (!post.isOwn)
              Expanded(
                child: PostKudosButton(
                  key: ValueKey('feed-kudos-button-${post.id}'),
                  hasKudoed: post.hasKudoed,
                  onTap: onKudosTap,
                ),
              ),
            Expanded(
              child: _ActionButton(
                key: ValueKey('feed-comment-button-${post.id}'),
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Komentarz',
                color: AppColors.textSecondary,
                onTap: onCommentTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Stos awatarów + „N kudosów” (tap → lista) i licznik komentarzy.
class PostSocialSummary extends StatelessWidget {
  const PostSocialSummary({
    super.key,
    required this.post,
    this.onKudosListTap,
    this.onCommentsTap,
  });

  final FeedPost post;
  final VoidCallback? onKudosListTap;
  final VoidCallback? onCommentsTap;

  @override
  Widget build(BuildContext context) {
    const countStyle = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
    );

    return Row(
      children: [
        if (post.kudosCount > 0)
          Flexible(
            child: InkWell(
              key: ValueKey('feed-kudos-summary-${post.id}'),
              onTap: onKudosListTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (post.recentKudos.isNotEmpty) ...[
                      StackedAvatars(authors: post.recentKudos),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        formatKudosCount(post.kudosCount),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: countStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const Spacer(),
        if (post.commentCount > 0)
          InkWell(
            onTap: onCommentsTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Text(
                formatCommentsCount(post.commentCount),
                style: countStyle,
              ),
            ),
          ),
      ],
    );
  }
}

class PostKudosButton extends StatelessWidget {
  const PostKudosButton({
    super.key,
    required this.hasKudoed,
    required this.onTap,
  });

  final bool hasKudoed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: hasKudoed,
      child: _ActionButton(
        icon: hasKudoed
            ? Icons.thumb_up_alt_rounded
            : Icons.thumb_up_alt_outlined,
        label: hasKudoed ? 'Dano kudosa' : 'Kudos',
        color: hasKudoed ? AppColors.primaryVariant : AppColors.textSecondary,
        onTap: onTap,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(icon, key: ValueKey(icon), size: 19, color: color),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
