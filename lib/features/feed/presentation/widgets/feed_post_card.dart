import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../training/presentation/widgets/new_records_banner.dart';
import '../../../training/presentation/widgets/session_details/session_details_formatters.dart';
import '../../domain/models/feed_post.dart';
import '../utils/feed_formatters.dart';
import 'feed_seen_markers.dart';
import 'post_author_row.dart';
import 'post_best_set.dart';
import 'post_muscle_chips.dart';
import 'post_photo.dart';
import 'post_social_bar.dart';

/// Karta posta w feedzie: autor, tytuł, notatka, panel statystyk,
/// „Nowy rekord!” albo najlepsza seria, partie mięśni i stopka
/// społecznościowa.
///
/// Czysto prezentacyjna — wszystkie akcje przychodzą z zewnątrz.
class FeedPostCard extends StatelessWidget {
  const FeedPostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onAuthorTap,
    this.onKudosTap,
    this.onKudosListTap,
    this.onCommentTap,
    this.now,
    this.showAuthor = true,
    this.isNew = false,
    this.compact = false,
    this.onEditTap,
    this.onUnshareTap,
  });

  final FeedPost post;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onKudosTap;
  final VoidCallback? onKudosListTap;
  final VoidCallback? onCommentTap;

  /// Test seam dla względnego znacznika czasu.
  final DateTime? now;

  /// `false` na osi czasu profilu — autor jest już w nagłówku ekranu, więc
  /// karta zaczyna się od daty.
  final bool showAuthor;

  /// Post nowy od ostatniej wizyty — plakietka „Nowy” przy autorze.
  final bool isNew;

  /// Krótsza karta na osi czasu profilu: bez najlepszej serii i partii
  /// mięśni (rekordy zostają), a własny post bez przycisku „Komentarz”.
  final bool compact;

  /// Menu „⋯” własnego posta na profilu: w wierszu autora albo (bez autora)
  /// w prawym górnym rogu karty.
  /// Pojawia się, gdy podano którąkolwiek z akcji.
  final VoidCallback? onEditTap;
  final VoidCallback? onUnshareTap;

  static const _radius = 24.0;

  @override
  Widget build(BuildContext context) {
    final note = post.note;
    final photoUrl = post.photoUrl;
    final bestSet = pickBestSetExercise(post.topExercises);
    // Z własnym tytułem nazwa treningu przechodzi do linii z datą.
    final timestamp = formatFeedTimestamp(post.startedAt, now: now);
    final hasMenu = onEditTap != null || onUnshareTap != null;
    final timestampLabel = post.postTitle == null
        ? timestamp
        : '$timestamp · ${post.title}';

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_radius),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.55),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.surfaceVariant.withValues(alpha: 0.55),
                      AppColors.surface,
                    ],
                    stops: const [0, 0.45],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showAuthor) ...[
                      PostAuthorRow(
                        author: post.author,
                        timestamp: timestampLabel,
                        onTap: onAuthorTap,
                        avatarSize: PostAuthorAvatarSize.large,
                        // Menu „⋯” w miejscu plakietki, na wysokości
                        // awatara (przesunięte ku krawędzi karty).
                        trailing: hasMenu
                            ? Transform.translate(
                                offset: const Offset(8, 0),
                                child: _OwnPostMenu(
                                  postId: post.id,
                                  onEdit: onEditTap,
                                  onUnshare: onUnshareTap,
                                ),
                              )
                            : post.isOwn
                            ? const _OwnBadge()
                            : isNew
                            ? const FeedNewBadge()
                            : null,
                      ),
                      const SizedBox(height: 14),
                    ] else ...[
                      _PostTimestamp(
                        label: timestampLabel,
                        trailingGap: hasMenu ? 32 : 0,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      post.headline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1.2,
                      ),
                    ),
                    if (note != null) ...[
                      const SizedBox(height: 6),
                      _PostBody(note: note),
                    ],
                    if (photoUrl != null) ...[
                      const SizedBox(height: 12),
                      PostPhoto(url: photoUrl, expandable: false),
                    ],
                    const SizedBox(height: 14),
                    _PostStatsPanel(
                      stats: [
                        _Stat(
                          icon: Icons.timer_outlined,
                          value: formatDuration(post.durationSec),
                          label: 'Czas',
                        ),
                        _Stat(
                          icon: Icons.fitness_center_rounded,
                          value: formatVolumeKg(post.totalVolumeKg),
                          label: 'Objętość',
                        ),
                        _Stat(
                          icon: Icons.layers_rounded,
                          value: '${post.completedSetsCount}',
                          label: 'Serie',
                        ),
                      ],
                    ),
                    // Rekordy mówią więcej niż najlepsza seria (zwykle to ta
                    // sama seria), więc zajmują jej miejsce.
                    if (post.personalRecords.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      NewRecordsBanner(
                        records: post.personalRecords,
                        maxVisible: 2,
                      ),
                    ] else if (!compact && bestSet != null) ...[
                      const SizedBox(height: 10),
                      PostBestSet(exercise: bestSet),
                    ],
                    if (!compact && post.muscles.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      PostMuscleChips(muscles: post.muscles),
                    ],
                    if (!(compact && post.isOwn) ||
                        post.kudosCount > 0 ||
                        post.commentCount > 0) ...[
                      const SizedBox(height: 14),
                      PostSocialBar(
                        post: post,
                        onKudosTap: onKudosTap,
                        onKudosListTap: onKudosListTap,
                        onCommentTap: onCommentTap,
                        showCommentButton: !(compact && post.isOwn),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasMenu && !showAuthor)
                Positioned(
                  top: 2,
                  right: 2,
                  child: _OwnPostMenu(
                    postId: post.id,
                    onEdit: onEditTap,
                    onUnshare: onUnshareTap,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _OwnPostAction { edit, unshare }

/// „⋯” w rogu własnego posta na profilu: edycja i wycofanie z profilu.
class _OwnPostMenu extends StatelessWidget {
  const _OwnPostMenu({required this.postId, this.onEdit, this.onUnshare});

  final String postId;
  final VoidCallback? onEdit;
  final VoidCallback? onUnshare;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_OwnPostAction>(
      key: ValueKey('profile-post-menu-$postId'),
      tooltip: 'Opcje posta',
      color: AppColors.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      icon: const Icon(
        Icons.more_horiz_rounded,
        color: AppColors.textSecondary,
        size: 22,
      ),
      iconSize: 22,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 220),
      style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      onSelected: (action) {
        switch (action) {
          case _OwnPostAction.edit:
            onEdit?.call();
          case _OwnPostAction.unshare:
            onUnshare?.call();
        }
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          const PopupMenuItem(
            value: _OwnPostAction.edit,
            height: 48,
            child: Row(
              children: [
                Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
                SizedBox(width: 12),
                Text(
                  'Edytuj post',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
              ],
            ),
          ),
        if (onUnshare != null)
          const PopupMenuItem(
            value: _OwnPostAction.unshare,
            height: 48,
            child: Row(
              children: [
                Icon(
                  Icons.visibility_off_outlined,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
                SizedBox(width: 12),
                Text(
                  'Przestań udostępniać',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PostTimestamp extends StatelessWidget {
  const _PostTimestamp({required this.label, this.trailingGap = 0});

  final String label;

  /// Wolne miejsce z prawej na przycisk menu nałożony na kartę.
  final double trailingGap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.fitness_center_rounded,
          size: 13,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(width: trailingGap),
      ],
    );
  }
}

class _OwnBadge extends StatelessWidget {
  const _OwnBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: const Text(
        'Twój trening',
        style: TextStyle(
          color: AppColors.primaryVariant,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Opis posta (notatka autora) — najwyżej trzy linie, „więcej” w
/// szczegółach posta.
class _PostBody extends StatelessWidget {
  const _PostBody({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Text(
      note,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.textSubtle,
        fontSize: 14,
        height: 1.45,
      ),
    );
  }
}

class _Stat {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;
}

/// Duże liczby w przyciemnionym panelu — główny „wynik” posta.
class _PostStatsPanel extends StatelessWidget {
  const _PostStatsPanel({required this.stats});

  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      if (i != 0) {
        children.add(
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(vertical: 6),
            color: AppColors.border.withValues(alpha: 0.5),
          ),
        );
      }
      children.add(Expanded(child: _StatCell(stat: stats[i])));
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.45)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.stat});

  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(stat.icon, size: 13, color: AppColors.primaryVariant),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  stat.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              stat.value,
              maxLines: 1,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
