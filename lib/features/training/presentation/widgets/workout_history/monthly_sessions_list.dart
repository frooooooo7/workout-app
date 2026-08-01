import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:gym/core/theme/app_colors.dart';
import 'package:gym/core/widgets/app_pressable.dart';
import '../../../domain/models/training_history_models.dart';

/// Lista sesji wybranego miesiąca. Każdy wiersz niesie ikonę treningu, nazwę
/// z datą oraz cztery metryki: czas, ćwiczenia, serie i objętość.
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
                  color: AppColors.border.withValues(alpha: 0.9),
                  height: 1,
                  thickness: 1.25,
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) =>
                    _SessionRow(session: sessions[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final TrainingSessionListItem session;

  @override
  Widget build(BuildContext context) {
    final title = session.plan.name.trim().isNotEmpty
        ? session.plan.name.trim()
        : 'Trening siłowy';

    return AppPressable(
      onTap: () => context.push('/app/training/history/${session.id}'),
      pressedScale: 0.98,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.32),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatDateTime(session.startedAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SessionMetricsRow(
              entries: [
                _Metric(_formatDuration(session.durationSec), 'Czas'),
                _Metric('${session.exercisesCount}', 'Ćwiczeń'),
                _Metric('${session.completedSetsCount}', 'Serie'),
                _Metric(_formatVolume(session.totalVolumeKg), 'Objętość'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric {
  const _Metric(this.value, this.label);

  final String value;
  final String label;
}

/// Cztery metryki w równych kolumnach, rozdzielone cienkimi separatorami —
/// ten sam język wizualny co karta statystyk miesiąca.
class _SessionMetricsRow extends StatelessWidget {
  const _SessionMetricsRow({required this.entries});

  final List<_Metric> entries;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      if (i != 0) {
        children.add(
          Container(
            width: 1,
            height: 26,
            color: AppColors.border.withValues(alpha: 0.35),
          ),
        );
      }
      children.add(Expanded(child: _MetricCell(metric: entries[i])));
    }
    return Row(children: children);
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          metric.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          metric.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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

// ---------------------------------------------------------------------------
// Formatowanie
// ---------------------------------------------------------------------------

const _monthNamesShort = [
  'sty',
  'lut',
  'mar',
  'kwi',
  'maj',
  'cze',
  'lip',
  'sie',
  'wrz',
  'paź',
  'lis',
  'gru',
];

String _formatDateTime(DateTime dt) {
  final local = dt.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_monthNamesShort[local.month - 1]} ${local.year} · $hour:$minute';
}

/// `mm:ss` poniżej godziny, `h:mm:ss` powyżej.
String _formatDuration(int seconds) {
  if (seconds <= 0) return '—';
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = secs.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

/// Tony z przecinkiem dziesiętnym od 1000 kg w górę, niżej pełne kilogramy.
String _formatVolume(double? volumeKg) {
  if (volumeKg == null || volumeKg <= 0) return '—';
  if (volumeKg >= 1000) {
    final tons = (volumeKg / 1000).toStringAsFixed(2).replaceAll('.', ',');
    return '$tons t';
  }
  return '${volumeKg.round()} kg';
}
