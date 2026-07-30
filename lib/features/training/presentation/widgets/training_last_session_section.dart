import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../domain/models/training_history_models.dart';
import '../bloc/training_history_cubit.dart';

class TrainingLastSessionSection extends StatelessWidget {
  const TrainingLastSessionSection({
    super.key,
    required this.state,
    required this.onOpenDetails,
    required this.onRepeat,
  });

  final TrainingHistoryState state;
  final ValueChanged<TrainingSessionListItem> onOpenDetails;
  final ValueChanged<TrainingSessionListItem> onRepeat;

  @override
  Widget build(BuildContext context) {
    final item = state.items.isEmpty ? null : state.items.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Ostatni trening',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),
            if (item != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Podsumowanie',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (state.loading && item == null)
          const _LastSessionSkeleton()
        else if (state.error != null && item == null)
          const _LastSessionMessage(
            icon: Icons.wifi_off_rounded,
            message: 'Nie udało się załadować ostatniego treningu.',
          )
        else if (item == null)
          const _LastSessionMessage(
            icon: Icons.emoji_events_outlined,
            message: 'Ukończ pierwszy trening, a tutaj go zobaczysz.',
          )
        else
          _LastSessionCard(
            item: item,
            onOpenDetails: () => onOpenDetails(item),
            onRepeat: () => onRepeat(item),
          ),
      ],
    );
  }
}

class _LastSessionCard extends StatelessWidget {
  const _LastSessionCard({
    required this.item,
    required this.onOpenDetails,
    required this.onRepeat,
  });

  final TrainingSessionListItem item;
  final VoidCallback onOpenDetails;
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    final highlight = item.progressHighlight;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Single Vertically-Centered Header Row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Dumbbell Icon Container with subtle primary blue tint
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Vertically Centered Title & Progress Badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.plan.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.2,
                        ),
                      ),
                      if (highlight != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: highlight.type ==
                                    TrainingProgressHighlightType.noProgress
                                ? AppColors.surfaceVariant.withValues(alpha: 0.7)
                                : AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: highlight.type ==
                                      TrainingProgressHighlightType.noProgress
                                  ? AppColors.border
                                  : AppColors.success.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                highlight.type ==
                                        TrainingProgressHighlightType.noProgress
                                    ? Icons.remove_circle_outline_rounded
                                    : Icons.trending_up_rounded,
                                size: 12,
                                color: highlight.type ==
                                        TrainingProgressHighlightType.noProgress
                                    ? AppColors.textMuted
                                    : AppColors.success,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                highlight.label,
                                style: TextStyle(
                                  color: highlight.type ==
                                          TrainingProgressHighlightType.noProgress
                                      ? AppColors.textMuted
                                      : AppColors.success,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Right Date Pill (Vertically Centered)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        relativeTrainingDayLabel(item.startedAt),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 2),

          // Structured Stat Tiles
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.timer_outlined,
                    label: 'CZAS',
                    value: formatDuration(item.durationSec),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    icon: Icons.fitness_center_rounded,
                    label: 'ĆWICZENIA',
                    value: '${item.exercisesCount}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    icon: Icons.repeat_rounded,
                    label: 'SERIE',
                    value: '${item.completedSetsCount}',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Equalized Action Buttons with Symmetrical Icons & Spring Feedback
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _AnimatedPressable(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        key: const ValueKey('last-session-repeat'),
                        onPressed: onRepeat,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.replay_rounded, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Powtórz',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AnimatedPressable(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        key: const ValueKey('last-session-details'),
                        onPressed: onOpenDetails,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor:
                              AppColors.surfaceVariant.withValues(alpha: 0.6),
                          side: BorderSide(
                            color: AppColors.border.withValues(alpha: 0.8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Szczegóły',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedPressable extends StatefulWidget {
  const _AnimatedPressable({required this.child});

  final Widget child;

  @override
  State<_AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<_AnimatedPressable>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _controller.forward(),
      onPointerUp: (_) => _controller.reverse(),
      onPointerCancel: (_) => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

String relativeTrainingDayLabel(DateTime startedAt, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final local = startedAt.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return 'Dzisiaj';
  if (diff == 1) return 'Wczoraj';
  if (diff < 7) return '$diff dni temu';
  return '${local.day}.${local.month.toString().padLeft(2, '0')}';
}

class _LastSessionSkeleton extends StatefulWidget {
  const _LastSessionSkeleton();

  @override
  State<_LastSessionSkeleton> createState() => _LastSessionSkeletonState();
}

class _LastSessionSkeletonState extends State<_LastSessionSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
          ),
        );
      },
    );
  }
}

class _LastSessionMessage extends StatelessWidget {
  const _LastSessionMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

