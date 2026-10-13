import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/models/body_weight_entry.dart';
import 'body_weight_chart.dart';

/// Karta wykresu masy ciała z legendą. Przy mniej niż dwóch pomiarach
/// w okresie — krótka informacja zamiast wykresu.
class BodyWeightChartCard extends StatelessWidget {
  const BodyWeightChartCard({
    super.key,
    required this.entries,
    required this.trendKg,
    this.goalKg,
  });

  /// Pomiary okresu, od najstarszego.
  final List<BodyWeightEntry> entries;

  /// Trend dla każdego z [entries].
  final List<double> trendKg;
  final double? goalKg;

  @override
  Widget build(BuildContext context) {
    final hasChart = entries.length >= 2;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 172,
            child: hasChart
                ? BodyWeightChart(
                    entries: entries,
                    trendKg: trendKg,
                    goalKg: goalKg,
                  )
                : const Center(
                    child: Text(
                      'Za mało pomiarów w tym okresie, żeby narysować wykres.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
          ),
          if (hasChart) ...[
            const SizedBox(height: 6),
            ExcludeSemantics(
              child: Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  const _LegendItem(
                    marker: _LineMarker(),
                    label: 'trend tygodniowy',
                  ),
                  const _LegendItem(marker: _DotMarker(), label: 'pomiary'),
                  if (goalKg != null)
                    const _LegendItem(marker: _DashMarker(), label: 'cel'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.marker, required this.label});

  final Widget marker;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        marker,
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LineMarker extends StatelessWidget {
  const _LineMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 3,
      decoration: BoxDecoration(
        color: AppColors.statTeal,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _DotMarker extends StatelessWidget {
  const _DotMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.statTeal.withValues(alpha: 0.45),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _DashMarker extends StatelessWidget {
  const _DashMarker();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < 3; i++)
            Container(width: 3.5, height: 2, color: AppColors.success),
        ],
      ),
    );
  }
}
