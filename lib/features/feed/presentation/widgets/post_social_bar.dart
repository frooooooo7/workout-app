import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/feed_post.dart';
import '../utils/feed_formatters.dart';
import 'stacked_avatars.dart';

/// Stopka posta: podsumowanie (awatary kudosów, liczniki) i akcje
/// „Kudos” / „Komentarz” w formie pigułek. Własny post nie ma przycisku kudosa.
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
            padding: const EdgeInsets.only(bottom: 10),
            child: PostSocialSummary(
              post: post,
              onKudosListTap: onKudosListTap,
              onCommentsTap: onCommentTap,
            ),
          ),
        Row(
          children: [
            if (!post.isOwn) ...[
              Expanded(
                child: PostKudosButton(
                  key: ValueKey('feed-kudos-button-${post.id}'),
                  hasKudoed: post.hasKudoed,
                  onTap: onKudosTap,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: _PillButton(
                key: ValueKey('feed-comment-button-${post.id}'),
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Komentarz',
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
                    ] else ...[
                      const _KudosGlyph(),
                      const SizedBox(width: 6),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chat_bubble_rounded,
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Text(formatCommentsCount(post.commentCount), style: countStyle),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _KudosGlyph extends StatelessWidget {
  const _KudosGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.primaryVariant, AppColors.primary],
        ),
      ),
      child: const Icon(Icons.thumb_up_rounded, size: 11, color: Colors.white),
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
    final onTap = this.onTap;
    return Semantics(
      toggled: hasKudoed,
      child: _PillButton(
        icon: hasKudoed
            ? Icons.thumb_up_alt_rounded
            : Icons.thumb_up_alt_outlined,
        label: hasKudoed ? 'Dano kudosa' : 'Kudos',
        active: hasKudoed,
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap();
              },
      ),
    );
  }
}

/// Zaokrąglony przycisk akcji. [active] = wypełnienie gradientem akcentu.
class _PillButton extends StatelessWidget {
  const _PillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  static const _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : AppColors.textSecondary;
    final radius = BorderRadius.circular(999);

    return AnimatedContainer(
      duration: _duration,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: active ? null : AppColors.surfaceVariant.withValues(alpha: 0.6),
        gradient: active
            ? const LinearGradient(
                colors: [AppColors.primaryVariant, AppColors.primary],
              )
            : null,
        border: Border.all(
          color: active
              ? Colors.transparent
              : AppColors.border.withValues(alpha: 0.7),
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : const [],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 42),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: _duration,
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                      ),
                      child: child,
                    ),
                    child: Icon(icon, key: ValueKey(icon), size: 18, color: color),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: AnimatedDefaultTextStyle(
                      duration: _duration,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
