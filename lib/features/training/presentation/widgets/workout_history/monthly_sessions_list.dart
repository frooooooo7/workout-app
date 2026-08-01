import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:gym/core/theme/app_colors.dart';
import 'package:gym/core/widgets/app_pressable.dart';
import '../../../domain/models/training_history_models.dart';
import '../session_details/session_details_formatters.dart';
import '../session_details/session_metrics_row.dart';

/// Lista sesji wybranego miesiąca — każda pozycja to karta w tym samym
/// układzie co [SessionSummaryHeader] na ekranie szczegółów sesji: ikona,
/// tytuł z datą, strzałka prowadząca do szczegółów i rząd metryk (czas /
/// ćwiczenia / serie / objętość), tylko w bardziej kompaktowym rozmiarze.
/// Chip statusu z nagłówka jest tu pominięty celowo — lista pokazuje
/// wyłącznie ukończone sesje (filtr `status: completed`), więc powtarzanie
/// zawsze tego samego „Ukończony" nie niosłoby informacji.
class MonthlySessionsList extends StatelessWidget {
  const MonthlySessionsList({
    super.key,
    required this.sessions,
    this.selectedDay,
  });

  final List<TrainingSessionListItem> sessions;
  final DateTime? selectedDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectedDay != null ? 'Treningi z wybranego dnia' : 'Treningi w miesiącu',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          if (sessions.isEmpty)
            _EmptySessionsState(selectedDay: selectedDay)
          else
            Column(
              children: [
                for (var i = 0; i < sessions.length; i++) ...[
                  if (i != 0) const SizedBox(height: 12),
                  _SessionCard(session: sessions[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final TrainingSessionListItem session;

  @override
  Widget build(BuildContext context) {
    final title = session.plan.name.trim().isNotEmpty
        ? session.plan.name.trim()
        : 'Trening siłowy';

    return AppPressable(
      onTap: () => context.push('/app/training/history/${session.id}'),
      pressedScale: 0.98,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                    border: Border.all(color: AppColors.primary, width: 1.4),
                  ),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        formatDateWithTime(session.startedAt),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SessionMetricsRow(
              entries: [
                SessionMetricSpec(
                  icon: Icons.access_time_rounded,
                  value: formatDigitalDuration(session.durationSec),
                  label: 'Czas',
                ),
                SessionMetricSpec(
                  icon: Icons.fitness_center_rounded,
                  value: '${session.exercisesCount}',
                  label: 'Ćwiczenia',
                ),
                SessionMetricSpec(
                  icon: Icons.layers_rounded,
                  value: '${session.completedSetsCount}',
                  label: 'Serie',
                ),
                SessionMetricSpec(
                  icon: Icons.monitor_weight_outlined,
                  value: formatVolumeKg(session.totalVolumeKg ?? 0),
                  label: 'Objętość',
                ),
              ],
            ),
          ],
        ),
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
