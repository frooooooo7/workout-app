import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../profile/domain/repositories/body_weight_repository.dart';
import '../../../../profile/domain/services/body_weight_trend.dart';
import '../../../../profile/presentation/bloc/body_weight_cubit.dart';
import '../../../../profile/presentation/screens/body_weight_screen.dart';
import '../../../../profile/presentation/utils/profile_details_labels.dart';
import '../../../../profile/presentation/widgets/body_weight_chart.dart';
import '../../../domain/models/training_stats.dart';
import '../session_details/session_section_card.dart';
import 'stats_format.dart';

const statsBodyWeightOpenKey = Key('stats-body-weight-open');

/// Masa ciała w zakresie statystyk: aktualna waga, zmiana w okresie i mały
/// wykres. Pomiary są tylko online — bez sieci karta znika (jak cel
/// tygodniowy). Stuknięcie otwiera pełny dziennik.
class StatsBodyWeightCard extends StatefulWidget {
  const StatsBodyWeightCard({
    super.key,
    required this.repository,
    required this.window,
  });

  final BodyWeightRepository repository;
  final StatsWindow window;

  @override
  State<StatsBodyWeightCard> createState() => _StatsBodyWeightCardState();
}

class _StatsBodyWeightCardState extends State<StatsBodyWeightCard> {
  late final BodyWeightCubit _cubit = BodyWeightCubit(widget.repository)
    ..load();

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _open() async {
    await context.push(kBodyWeightRoute);
    if (mounted) await _cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BodyWeightCubit, BodyWeightState>(
      bloc: _cubit,
      builder: (context, state) {
        final entries = state.entries;
        // Bez danych (ładowanie, błąd) karta nie zajmuje miejsca.
        if (entries == null || (state.loadError != null && entries.isEmpty)) {
          return const SizedBox.shrink();
        }
        return InkWell(
          key: statsBodyWeightOpenKey,
          onTap: _open,
          borderRadius: BorderRadius.circular(18),
          child: SessionSectionCard(
            icon: Icons.monitor_weight_outlined,
            title: 'Masa ciała',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
            ),
            child: entries.isEmpty
                ? const Text(
                    'Zapisuj wagę, żeby widzieć jej zmiany obok treningów. '
                    'Stuknij, aby dodać pierwszy pomiar.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  )
                : _Summary(state: state, window: widget.window),
          ),
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.state, required this.window});

  final BodyWeightState state;
  final StatsWindow window;

  @override
  Widget build(BuildContext context) {
    final latest = state.latest!;
    // Koniec okna statystyk jest wyłączny.
    final end = window.end.subtract(const Duration(days: 1));
    final inRange = bodyWeightEntriesBetween(
      state.entries!,
      start: window.start,
      end: end,
    );
    final trend = bodyWeightTrend(inRange);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                formatWeightKg(latest.weightKg),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            Text(
              trend == null
                  ? 'pomiar ${formatStatsDayMonth(latest.date)}'
                  : '${formatWeightChange(trend.changeKg)} w tym okresie',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (inRange.length >= 2) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 64,
            child: BodyWeightChart(entries: inRange, compact: true),
          ),
        ],
      ],
    );
  }
}
