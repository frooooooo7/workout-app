import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../training/presentation/widgets/session_details/session_details_formatters.dart';
import '../../../training/presentation/widgets/session_details/session_metrics_row.dart';
import '../../domain/models/feed_post.dart';
import '../utils/feed_formatters.dart';
import 'post_author_row.dart';
import 'post_muscle_chips.dart';
import 'post_social_bar.dart';
import 'post_top_exercises.dart';

/// Karta posta w feedzie (w stylu Stravy): autor, tytuł, notatka, metryki,
/// najważniejsze ćwiczenia, partie mięśni i stopka społecznościowa.
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
  });

  final FeedPost post;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onKudosTap;
  final VoidCallback? onKudosListTap;
  final VoidCallback? onCommentTap;

  /// Test seam dla względnego znacznika czasu.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final note = post.note;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PostAuthorRow(
                author: post.author,
                timestamp: formatFeedTimestamp(post.startedAt, now: now),
                onTap: onAuthorTap,
              ),
              const SizedBox(height: 12),
              Text(
                post.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              if (note != null) ...[
                const SizedBox(height: 6),
                Text(
                  note,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SessionMetricsRow(
                entries: [
                  SessionMetricSpec(
                    icon: Icons.access_time_rounded,
                    value: formatDuration(post.durationSec),
                    label: 'Czas',
                  ),
                  SessionMetricSpec(
                    icon: Icons.monitor_weight_outlined,
                    value: formatVolumeKg(post.totalVolumeKg),
                    label: 'Objętość',
                  ),
                  SessionMetricSpec(
                    icon: Icons.layers_rounded,
                    value: '${post.completedSetsCount}',
                    label: 'Serie',
                  ),
                ],
              ),
              if (post.topExercises.isNotEmpty) ...[
                const SizedBox(height: 14),
                PostTopExercises(
                  exercises: post.topExercises,
                  totalExercises: post.exercisesCount,
                ),
              ],
              if (post.muscles.isNotEmpty) ...[
                const SizedBox(height: 10),
                PostMuscleChips(muscles: post.muscles),
              ],
              const SizedBox(height: 12),
              PostSocialBar(
                post: post,
                onKudosTap: onKudosTap,
                onKudosListTap: onKudosListTap,
                onCommentTap: onCommentTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
