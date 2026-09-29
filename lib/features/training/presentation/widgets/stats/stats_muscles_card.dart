import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../../body_highlighter/adapters/muscle_group_adapter.dart';
import '../../../../body_highlighter/models/body_highlighter_style.dart';
import '../../../../body_highlighter/models/body_view.dart' as bh;
import '../../../../body_highlighter/models/muscle_highlight.dart';
import '../../../../body_highlighter/widgets/muscle_body_highlighter.dart';
import '../../../../library/domain/models/exercise.dart';
import '../../../domain/models/training_stats.dart';
import '../session_details/session_section_card.dart';
import 'stats_format.dart';

/// Kolor partii ciała — ten sam na donucie, w legendzie i na paskach rankingu.
Color _regionColor(MuscleRegion region) => switch (region) {
  MuscleRegion.chest => AppColors.statPink,
  MuscleRegion.back => AppColors.primaryVariant,
  MuscleRegion.shoulders => AppColors.statOrange,
  MuscleRegion.arms => AppColors.statTeal,
  MuscleRegion.core => AppColors.statAmber,
  MuscleRegion.legs => AppColors.statIndigo,
};

/// Rozkład pracy na partie i mięśnie w zakresie: donut partii, manekin
/// podświetlony intensywnością, ranking mięśni i ostrzeżenie o pominiętych.
class StatsMusclesCard extends StatefulWidget {
  const StatsMusclesCard({super.key, required this.muscles});

  final MuscleDistribution muscles;

  @override
  State<StatsMusclesCard> createState() => _StatsMusclesCardState();
}

class _StatsMusclesCardState extends State<StatsMusclesCard> {
  static const _collapsedRows = 6;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.muscles;
    return SessionSectionCard(
      icon: Icons.accessibility_new_rounded,
      title: 'Partie mięśni',
      child: m.isEmpty
          ? const _MutedNote(
              icon: Icons.accessibility_new_rounded,
              text: 'Dodaj partie mięśni do ćwiczeń, aby zobaczyć rozkład.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Liczone w seriach; mięśnie wspomagające po połowie.',
                  style: _captionStyle,
                ),
                const SizedBox(height: AppSpacing.md),
                if (m.regions.isNotEmpty) ...[
                  const _SubHeader('PODZIAŁ NA PARTIE'),
                  const SizedBox(height: AppSpacing.sm),
                  _RegionDonut(regions: m.regions),
                  const SizedBox(height: AppSpacing.lg),
                ],
                const _SubHeader('MAPA OBCIĄŻENIA'),
                const SizedBox(height: AppSpacing.sm),
                _BodyMap(muscles: m.muscles),
                const SizedBox(height: AppSpacing.lg),
                const _SubHeader('RANKING MIĘŚNI'),
                const SizedBox(height: AppSpacing.xs),
                _MuscleRanking(
                  muscles: _expanded
                      ? m.muscles
                      : m.muscles.take(_collapsedRows).toList(),
                  leaderSets: m.muscles.first.sets,
                ),
                if (m.muscles.length > _collapsedRows)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryVariant,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      icon: Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                      ),
                      label: Text(_expanded ? 'Zwiń' : 'Pokaż wszystkie'),
                    ),
                  ),
                if (m.neglected.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _NeglectedRow(muscles: m.neglected),
                ],
              ],
            ),
    );
  }
}

const _captionStyle = TextStyle(
  color: AppColors.textMuted,
  fontSize: 12,
  fontWeight: FontWeight.w500,
  height: 1.35,
);

class _SubHeader extends StatelessWidget {
  const _SubHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
      ),
    );
  }
}

class _RegionDonut extends StatelessWidget {
  const _RegionDonut({required this.regions});

  final List<RegionStat> regions;

  static const _size = 120.0;

  @override
  Widget build(BuildContext context) {
    final total = regions.fold<double>(0, (a, r) => a + r.sets);
    return Row(
      children: [
        SizedBox.square(
          dimension: _size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: regions.length > 1 ? 2 : 0,
                  centerSpaceRadius: 42,
                  pieTouchData: PieTouchData(enabled: false),
                  sections: [
                    for (final r in regions)
                      PieChartSectionData(
                        value: r.sets,
                        color: _regionColor(r.region),
                        radius: 15,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatStatsDecimal(total),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    _setsLabel(total),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in regions)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _regionColor(r.region),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          r.region.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${(r.share * 100).round()}%',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BodyMap extends StatelessWidget {
  const _BodyMap({required this.muscles});

  final List<MuscleStat> muscles;

  static const _style = BodyHighlighterStyle.dark();

  /// Kilka grup trafia w ten sam obszar manekina (np. najszersze
  /// i romboidalne) — obszar świeci intensywnością najmocniejszej z nich.
  Set<MuscleHighlight> _highlights() {
    final bySlug = <String, double>{};
    for (final m in muscles) {
      final slug = m.muscle.bodyHighlighterSlug;
      if (m.intensity > (bySlug[slug] ?? 0)) bySlug[slug] = m.intensity;
    }
    return {
      for (final e in bySlug.entries)
        MuscleHighlight(
          muscle: e.key,
          intensity: intensityToMuscleIntensity(e.value),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final highlights = _highlights();
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Figure(
              view: bh.BodyView.front,
              label: 'Przód',
              highlights: highlights,
            ),
            const SizedBox(width: AppSpacing.lg),
            _Figure(
              view: bh.BodyView.back,
              label: 'Tył',
              highlights: highlights,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('mniej', style: _captionStyle),
            const SizedBox(width: 6),
            for (final color in [
              _style.lowColor,
              _style.mediumColor,
              _style.highColor,
            ])
              Container(
                width: 18,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            const SizedBox(width: 6),
            const Text('więcej', style: _captionStyle),
          ],
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.view,
    required this.label,
    required this.highlights,
  });

  final bh.BodyView view;
  final String label;
  final Set<MuscleHighlight> highlights;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 88,
          height: 196,
          child: MuscleBodyHighlighter(
            view: view,
            highlights: highlights,
            style: _BodyMap._style,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MuscleRanking extends StatelessWidget {
  const _MuscleRanking({required this.muscles, required this.leaderSets});

  final List<MuscleStat> muscles;
  final double leaderSets;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final m in muscles)
          _MuscleBar(
            stat: m,
            fill: leaderSets > 0 ? (m.sets / leaderSets).clamp(0, 1) : 0,
          ),
      ],
    );
  }
}

class _MuscleBar extends StatelessWidget {
  const _MuscleBar({required this.stat, required this.fill});

  final MuscleStat stat;
  final double fill;

  @override
  Widget build(BuildContext context) {
    final sets = formatStatsDecimal(stat.sets);
    final percent = (stat.share * 100).round();
    final region = stat.muscle.region;
    final color = region == null
        ? AppColors.primaryVariant
        : _regionColor(region);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          '${stat.muscle.label}: $sets ${_setsLabel(stat.sets)}, '
          '$percent procent',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    stat.muscle.shortLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  sets,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  ' ${_setsLabel(stat.sets)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                ConstrainedBox(
                  // Minimalna szerokość wyrównuje kolumnę; przy dużej czcionce
                  // pole rośnie zamiast łamać „33%” na kilka linii.
                  constraints: const BoxConstraints(minWidth: 40),
                  child: Text(
                    '$percent%',
                    maxLines: 1,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fill),
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 5,
                  backgroundColor: AppColors.chartTrack,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NeglectedRow extends StatelessWidget {
  const _NeglectedRow({required this.muscles});

  final List<MuscleGroup> muscles;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.statAmber.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.statAmber.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: AppColors.statAmber,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Bez serii w tym okresie: ',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  TextSpan(
                    text: muscles.map((m) => m.label).join(', '),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _MutedNote extends StatelessWidget {
  const _MutedNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// Serie bywają ułamkowe — „12,5 serii” (ułamek zawsze w dopełniaczu).
String _setsLabel(double sets) {
  final rounded = double.parse(sets.toStringAsFixed(1));
  if (rounded != rounded.roundToDouble()) return 'serii';
  return polishPlural(rounded.round(), 'seria', 'serie', 'serii');
}
