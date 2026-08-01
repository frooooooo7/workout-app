import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:gym/core/theme/app_colors.dart';
import 'package:gym/core/widgets/app_pressable.dart';
import '../../../domain/models/training_history_models.dart';

class MonthlySessionsList extends StatelessWidget {
  const MonthlySessionsList({
    super.key,
    required this.sessions,
    this.selectedDay,
    this.onResetDayFilter,
  });

  final List<TrainingSessionListItem> sessions;
  final DateTime? selectedDay;
  final VoidCallback? onResetDayFilter;

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0m';
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year}, $hour:$minute';
  }

  String _formatVolume(double? volumeKg) {
    if (volumeKg == null || volumeKg <= 0) return '0 kg';
    if (volumeKg >= 1000) {
      return '${(volumeKg / 1000).toStringAsFixed(1)} t';
    }
    return '${volumeKg.round()} kg';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title + Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                selectedDay != null ? 'Treningi z wybranego dnia' : 'Ostatnie treningi',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              if (selectedDay != null && onResetDayFilter != null)
                GestureDetector(
                  onTap: onResetDayFilter,
                  child: const Text(
                    'Zobacz wszystkie',
                    style: TextStyle(
                      color: AppColors.primaryVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // List or Empty state
          if (sessions.isEmpty)
            _EmptySessionsState(selectedDay: selectedDay)
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.8),
                  width: 1,
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sessions.length,
                separatorBuilder: (context, index) => Divider(
                  color: AppColors.border.withValues(alpha: 0.4),
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  final title = session.plan.name.trim().isNotEmpty
                      ? session.plan.name
                      : 'Trening siłowy';

                  return AppPressable(
                    onTap: () {
                      context.push('/app/training/history/${session.id}');
                    },
                    pressedScale: 0.98,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Session Icon Container
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.fitness_center_rounded,
                              color: AppColors.primaryVariant,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Session Main Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      _formatDateTime(session.startedAt),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 3,
                                      height: 3,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDuration(session.durationSec),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '${session.exercisesCount} ćwiczeń • ${session.completedSetsCount} serii',
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                    if (session.totalVolumeKg != null &&
                                        session.totalVolumeKg! > 0) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '(${_formatVolume(session.totalVolumeKg)})',
                                        style: const TextStyle(
                                          color: AppColors.primaryVariant,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Chevron Trailing Icon
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptySessionsState extends StatelessWidget {
  const _EmptySessionsState({this.selectedDay});

  final DateTime? selectedDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          Icon(
            selectedDay != null
                ? Icons.event_busy_rounded
                : Icons.fitness_center_rounded,
            color: AppColors.textMuted,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            selectedDay != null
                ? 'Brak treningu w tym dniu'
                : 'Brak zarejestrowanych treningów w tym miesiącu',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
