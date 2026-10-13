import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/animated_number.dart';
import '../../../domain/models/monthly_training_history.dart';
import '../session_details/session_details_formatters.dart';
import 'history_formatters.dart';

/// Nawigator miesiąca: strzałki poprzedni/następny, nazwa miesiąca
/// (stuknięcie otwiera wybór roku i miesiąca) i podsumowanie w jednej linii:
/// `9 treningów · 9 h 20 min · 50,2 t`.
class HistoryMonthNavigator extends StatelessWidget {
  const HistoryMonthNavigator({
    super.key,
    required this.month,
    required this.stats,
    required this.onPrevious,
    required this.onNext,
    required this.onPickMonth,
  });

  final DateTime month;

  /// `null`, dopóki miesiąc się nie wczytał.
  final MonthlyTrainingStats? stats;

  /// `null` wyłącza strzałkę (koniec dostępnego zakresu).
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onPickMonth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ArrowButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Poprzedni miesiąc',
          onPressed: onPrevious,
        ),
        Expanded(
          child: Tooltip(
            message: 'Wybierz rok/miesiąc',
            child: InkWell(
              onTap: onPickMonth,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatMonthYear(month),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _MonthSummary(stats: stats),
                  ],
                ),
              ),
            ),
          ),
        ),
        _ArrowButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Następny miesiąc',
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 26),
      color: AppColors.iconOnTile,
      disabledColor: AppColors.borderStrong,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(AppSpacing.minTapTarget),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.tile),
        ),
      ),
    );
  }
}

/// Liczba treningów, łączny czas i objętość — liczby doliczają się przy
/// zmianie miesiąca.
class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.stats});

  final MonthlyTrainingStats? stats;

  static final _style = AppTextStyles.tabular(
    const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
    ),
  );

  static const _duration = Duration(milliseconds: 600);

  @override
  Widget build(BuildContext context) {
    final s = stats;
    if (s == null) return Text(' ', style: _style);
    if (s.totalSessions == 0) return Text('Brak treningów', style: _style);

    Widget number(double value, String Function(double) format) =>
        AnimatedNumber(
          value: value,
          format: format,
          style: _style,
          duration: _duration,
          curve: Curves.easeOutExpo,
        );
    final separator = Text(' · ', style: _style);

    // Na wąskim ekranie (albo z dużym tekstem) linia się zmniejsza, zamiast
    // się zawijać.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          number(
            s.totalSessions.toDouble(),
            (v) => formatWorkoutCount(v.round()),
          ),
          separator,
          number(
            s.totalDurationSec.toDouble(),
            (v) => formatHoursMinutes(v.round()),
          ),
          if (s.totalVolumeKg > 0) ...[
            separator,
            number(s.totalVolumeKg, formatVolumeKg),
          ],
        ],
      ),
    );
  }
}
