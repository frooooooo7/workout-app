import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../domain/models/training_history_models.dart';
import '../../../domain/services/history_week_grouper.dart';
import '../../../domain/services/training_summary_calculator.dart';
import '../session_details/session_details_formatters.dart';
import 'history_formatters.dart';
import 'history_session_row.dart';

/// Sesje miesiąca pogrupowane tygodniami, każdy tydzień z sumą: „Ten tydzień
/// · 12–18 paź … 3 treningi · 17,1 t”. Gdy w kalendarzu wybrano dzień, lista
/// pokazuje tylko jego sesje i przycisk powrotu do całego miesiąca.
class HistoryWeekSessionsList extends StatelessWidget {
  const HistoryWeekSessionsList({
    super.key,
    required this.sessions,
    required this.today,
    this.selectedDay,
    this.recordsBySession = const {},
    this.onClearDay,
  });

  final List<TrainingSessionListItem> sessions;
  final DateTime today;
  final DateTime? selectedDay;
  final Map<String, int> recordsBySession;
  final VoidCallback? onClearDay;

  @override
  Widget build(BuildContext context) {
    final day = selectedDay;
    final groups = groupSessionsByWeek(sessions);
    final thisWeek = TrainingSummaryCalculator.startOfWeek(today);
    final lastWeek = DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      sliver: SliverMainAxisGroup(
        slivers: [
          if (day != null)
            SliverToBoxAdapter(
              child: _DayFilterBar(day: day, onClear: onClearDay),
            ),
          if (groups.isEmpty)
            SliverToBoxAdapter(child: _EmptySessions(dayFiltered: day != null))
          else
            for (final group in groups) ...[
              SliverToBoxAdapter(
                child: _WeekHeader(
                  group: group,
                  title: group.weekStart == thisWeek
                      ? 'Ten tydzień'
                      : group.weekStart == lastWeek
                      ? 'Poprzedni tydzień'
                      : null,
                ),
              ),
              SliverList.separated(
                itemCount: group.sessions.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final session = group.sessions[index];
                  return HistorySessionRow(
                    session: session,
                    recordsCount: recordsBySession[session.id] ?? 0,
                  );
                },
              ),
            ],
        ],
      ),
    );
  }
}

/// Nagłówek tygodnia: nazwa (albo sam zakres dat) i suma tygodnia.
class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.group, this.title});

  final HistoryWeekGroup group;

  /// „Ten tydzień” / „Poprzedni tydzień”; starsze tygodnie mają tylko daty.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final range = formatWeekRange(group.weekStart, group.weekEnd);
    final volume = group.totalVolumeKg;
    final summary = [
      formatWorkoutCount(group.sessions.length),
      if (volume > 0) formatVolumeKg(volume),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, AppSpacing.md, 2, AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: title ?? range),
                  if (title != null)
                    TextSpan(
                      text: ' · $range',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            summary,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Aktywny filtr dnia z kalendarza.
class _DayFilterBar extends StatelessWidget {
  const _DayFilterBar({required this.day, this.onClear});

  final DateTime day;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Treningi z dnia ${formatSessionDay(day)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryVariant,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Pokaż cały miesiąc'),
          ),
        ],
      ),
    );
  }
}

class _EmptySessions extends StatelessWidget {
  const _EmptySessions({required this.dayFiltered});

  final bool dayFiltered;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xl,
        horizontal: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            dayFiltered
                ? Icons.event_busy_rounded
                : Icons.fitness_center_rounded,
            color: AppColors.textMuted,
            size: 28,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            dayFiltered
                ? 'Brak treningu w tym dniu'
                : 'Brak zarejestrowanych treningów w tym miesiącu',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
