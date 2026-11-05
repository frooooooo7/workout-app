import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import 'workout_colors.dart';

/// Chipy pod nazwą ćwiczenia: „Ostatnio 92,5 × 6” (najlepsza seria
/// poprzedniego treningu) i złoty „Rekord 92,5 × 6”. Bez danych chip znika.
class ExerciseStatChips extends StatelessWidget {
  const ExerciseStatChips({
    super.key,
    this.last,
    this.record,
    this.recordLabel = 'Rekord',
  });

  final String? last;
  final String? record;

  /// „Rekord”, a w kardio „Tempo” (najszybsze z historii).
  final String recordLabel;

  @override
  Widget build(BuildContext context) {
    if (last == null && record == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (last != null)
            _Chip(
              key: const Key('exercise-last-chip'),
              label: 'Ostatnio',
              value: last!,
              background: WorkoutColors.chip,
              labelColor: WorkoutColors.textSoft,
              valueColor: AppColors.textPrimary,
            ),
          if (record != null)
            _Chip(
              key: const Key('exercise-record-chip'),
              icon: Icons.emoji_events_outlined,
              label: recordLabel,
              value: record!,
              background: AppColors.record.withValues(alpha: 0.12),
              labelColor: WorkoutColors.recordText,
              valueColor: AppColors.record,
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.value,
    required this.background,
    required this.labelColor,
    required this.valueColor,
    this.icon,
  });

  final String label;
  final String value;
  final Color background;
  final Color labelColor;
  final Color valueColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.record),
            const SizedBox(width: 5),
          ],
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$label '),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: valueColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            style: TextStyle(
              color: labelColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
