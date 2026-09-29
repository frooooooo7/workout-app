import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../domain/models/training_stats.dart';
import '../session_details/session_section_card.dart';

/// Podział ukończonych serii na zakresy powtórzeń: siła, masa, wytrzymałość.
class StatsRepRangesCard extends StatelessWidget {
  const StatsRepRangesCard({super.key, required this.ranges});

  final RepRangeDistribution ranges;

  @override
  Widget build(BuildContext context) {
    final dominant = ranges.dominant;
    final percents = _percents(ranges);
    return SessionSectionCard(
      icon: Icons.repeat_rounded,
      title: 'Zakresy powtórzeń',
      child: dominant == null
          ? const Text(
              'Brak serii z podaną liczbą powtórzeń w tym okresie.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StackedBar(ranges: ranges),
                const SizedBox(height: AppSpacing.sm),
                for (final range in RepRange.values)
                  _LegendRow(
                    range: range,
                    sets: ranges.setsOf(range),
                    percent: percents[range]!,
                  ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _caption(dominant),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
    );
  }
}

Color _rangeColor(RepRange range) => switch (range) {
  RepRange.strength => AppColors.statPink,
  RepRange.hypertrophy => AppColors.primaryVariant,
  RepRange.endurance => AppColors.statTeal,
};

String _caption(RepRange dominant) {
  final zone = switch (dominant) {
    RepRange.strength => 'siły',
    RepRange.hypertrophy => 'masy',
    RepRange.endurance => 'wytrzymałości',
  };
  return 'Najwięcej serii robisz w zakresie $zone (${dominant.reps} powt.).';
}

/// Procenty zaokrąglone tak, żeby dawały równo 100 (największa reszta).
Map<RepRange, int> _percents(RepRangeDistribution ranges) {
  final total = ranges.total;
  final result = {for (final r in RepRange.values) r: 0};
  if (total == 0) return result;

  final remainders = <RepRange, double>{};
  var used = 0;
  for (final r in RepRange.values) {
    final exact = ranges.setsOf(r) * 100 / total;
    result[r] = exact.floor();
    remainders[r] = exact - exact.floor();
    used += result[r]!;
  }
  // Remis rozstrzyga kolejność zakresów, żeby wynik był stały.
  final order = RepRange.values.toList()
    ..sort((a, b) {
      final byRemainder = remainders[b]!.compareTo(remainders[a]!);
      return byRemainder != 0 ? byRemainder : a.index.compareTo(b.index);
    });
  for (var i = 0; i < 100 - used; i++) {
    result[order[i]] = result[order[i]]! + 1;
  }
  return result;
}

/// Jeden pasek w trzech odcinkach, z 2-pikselowymi przerwami.
class _StackedBar extends StatelessWidget {
  const _StackedBar({required this.ranges});

  final RepRangeDistribution ranges;

  static const _height = 12.0;
  static const _gap = 2.0;
  static const _minSegment = 3.0;

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final r in RepRange.values)
        if (ranges.setsOf(r) > 0) r,
    ];

    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          height: _height,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final free =
                  constraints.maxWidth - _gap * math.max(0, visible.length - 1);
              final widths = _segmentWidths([
                for (final r in visible) ranges.shareOf(r),
              ], free);
              return Row(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: widths[i]),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, w, _) => SizedBox(
                        width: w,
                        height: _height,
                        child: ColoredBox(color: _rangeColor(visible[i])),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Szerokości odcinków; każdy niepusty ma co najmniej [_minSegment], a
  /// nadwyżkę oddaje największy.
  static List<double> _segmentWidths(List<double> shares, double free) {
    final widths = [for (final s in shares) math.max(_minSegment, s * free)];
    final excess = widths.fold<double>(0, (a, b) => a + b) - free;
    if (excess > 0 && widths.isNotEmpty) {
      var largest = 0;
      for (var i = 1; i < widths.length; i++) {
        if (widths[i] > widths[largest]) largest = i;
      }
      widths[largest] = math.max(_minSegment, widths[largest] - excess);
    }
    return widths;
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.range,
    required this.sets,
    required this.percent,
  });

  final RepRange range;
  final int sets;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final color = _rangeColor(range);
    final empty = sets == 0;
    final setsText = '$sets ${polishPlural(sets, 'seria', 'serie', 'serii')}';
    // Niepusty zakres nie może wyglądać jak zero.
    final percentText = !empty && percent == 0 ? '<1%' : '$percent%';

    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          '${range.label}, powtórzenia ${range.reps}: $setsText, '
          '$percentText',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: empty ? color.withValues(alpha: 0.35) : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: range.label,
                      style: TextStyle(
                        color: empty
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: ' · ${range.reps}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              setsText,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                percentText,
                textAlign: TextAlign.right,
                maxLines: 1,
                style: TextStyle(
                  color: empty
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
