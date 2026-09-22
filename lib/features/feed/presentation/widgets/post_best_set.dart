import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../training/presentation/widgets/session_details/session_details_formatters.dart';
import '../../domain/models/feed_post.dart';

/// Wyróżnienie najmocniejszej serii treningu: nazwa ćwiczenia + wynik.
class PostBestSet extends StatelessWidget {
  const PostBestSet({super.key, required this.exercise});

  final TopExercise exercise;

  static const _accent = AppColors.strengthMedium;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            _accent.withValues(alpha: 0.14),
            _accent.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(color: _accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: _accent,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NAJLEPSZA SERIA',
                  style: TextStyle(
                    color: _accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  exercise.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatSetMetrics(exercise.bestSet),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}
