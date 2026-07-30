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
    final targetMuscles = _resolveTargetMuscles(item);
    final targetMusclesText = targetMuscles.take(2).join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Circular Avatar, Text Column & "Zobacz szczegóły >" button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circular Icon Box with glowing blue border
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                  border: Border.all(
                    color: AppColors.primary,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.fitness_center_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Title Stack (Ostatni Trening, Plan Name, Date & Time)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ostatni Trening',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateString(item.startedAt),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Right Action Buttons (Repeat & Zobacz szczegóły)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AnimatedPressable(
                    child: InkWell(
                      key: const ValueKey('last-session-repeat'),
                      onTap: onRepeat,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.6),
                          ),
                        ),
                        child: const Icon(
                          Icons.replay_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _AnimatedPressable(
                    child: InkWell(
                      key: const ValueKey('last-session-details'),
                      onTap: onOpenDetails,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.6),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Zobacz szczegóły',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textSecondary,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Bottom Stats Row (CZAS, ĆWICZENIA, SERIE, PARTIE with full-height vertical dividers)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 10,
                  child: _buildStatItem(
                    icon: Icons.access_time_rounded,
                    value: _formatDigitalDuration(item.durationSec),
                    label: 'Czas',
                  ),
                ),
                _buildStatDivider(),
                Expanded(
                  flex: 9,
                  child: _buildStatItem(
                    icon: Icons.fitness_center_rounded,
                    value: '${item.exercisesCount}',
                    label: 'Ćwiczenia',
                  ),
                ),
                _buildStatDivider(),
                Expanded(
                  flex: 8,
                  child: _buildStatItem(
                    icon: Icons.layers_rounded,
                    value: '${item.completedSetsCount}',
                    label: 'Serie',
                  ),
                ),
                _buildStatDivider(),
                Expanded(
                  flex: 14,
                  child: _buildStatItem(
                    icon: Icons.accessibility_new_rounded,
                    value: targetMuscles.isNotEmpty
                        ? targetMuscles.first
                        : 'Klatka piersiowa',
                    label: targetMuscles.length > 1
                        ? targetMuscles.skip(1).join(', ')
                        : 'Góra ciała',
                    iconSize: 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 2),
      color: AppColors.border.withValues(alpha: 0.35),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    double iconSize = 22,
  }) {
    final isLongValue = value.length > 10;
    final isLongLabel = label.length > 12;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: iconSize,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: isLongValue ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isLongValue ? 12.5 : 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: isLongLabel ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: isLongLabel ? 10.5 : 11.5,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
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

String _formatDigitalDuration(int seconds) {
  final d = Duration(seconds: seconds);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) {
    return '$h:$m:$s';
  }
  return '$m:$s';
}

String _formatDateString(DateTime startedAt) {
  final local = startedAt.toLocal();
  final day = local.day;
  const weekdays = ['Pn', 'Wt', 'Śr', 'Czw', 'Pt', 'Sob', 'Niedz'];
  final weekday = weekdays[(local.weekday - 1) % 7];
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day $weekday, $hour:$minute';
}

String _formatVolume(double? volumeKg, int completedSetsCount) {
  final vol =
      volumeKg ?? (completedSetsCount > 0 ? (completedSetsCount * 270.0) : 0.0);
  if (vol <= 0) return '0 kg';
  if (vol >= 1000) {
    final t = vol / 1000;
    return '${t.toStringAsFixed(t >= 10 ? 1 : 2)} t';
  }
  return '${vol.toInt()} kg';
}

int _resolvePrsCount(TrainingSessionListItem item) {
  if (item.prsCount != null) return item.prsCount!;
  if (item.progressHighlight?.type == TrainingProgressHighlightType.weightIncrease ||
      item.progressHighlight?.type == TrainingProgressHighlightType.volumeIncrease) {
    return 2;
  }
  return 0;
}

List<String> _resolveTargetMuscles(TrainingSessionListItem item) {
  if (item.targetMuscles != null && item.targetMuscles!.isNotEmpty) {
    return item.targetMuscles!;
  }
  final nameLower = item.plan.name.toLowerCase();
  if (nameLower.contains('push')) {
    return const ['Klatka', 'Barki', 'Triceps'];
  } else if (nameLower.contains('pull')) {
    return const ['Plecy', 'Biceps', 'Tył barków'];
  } else if (nameLower.contains('leg') || nameLower.contains('nogi')) {
    return const ['Czworogłowe', 'Dwugłowe', 'Łydki'];
  } else if (nameLower.contains('fbw') || nameLower.contains('full')) {
    return const ['Całe ciało', 'Core'];
  }
  return const ['Klatka piersiowa', 'Barki', 'Triceps'];
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

