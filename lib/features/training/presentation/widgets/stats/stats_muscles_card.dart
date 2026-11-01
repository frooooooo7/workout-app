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
import '../../../../library/presentation/widgets/exercise_details/exercise_muscle_map.dart'
    show exercisePrimaryMuscleColor, exerciseSecondaryMuscleColor;
import '../../../domain/models/training_stats.dart';
import '../../../domain/services/muscle_roles.dart';
import '../session_details/session_details_formatters.dart' show formatVolumeKg;
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

/// Etykieta pozycji rankingu: grupy zbiorcze pełną nazwą („Nogi”, „Plecy”,
/// „Barki”), granularne skróconą, żeby zmieściły się w wąskim wierszu.
String _rankLabel(MuscleGroup group) =>
    group.isCoarse ? group.label : group.shortLabel;

/// Rozkład pracy na partie i mięśnie w zakresie: donut partii, manekin
/// podświetlony rolami mięśni ([MuscleDistribution.bodyRoles]), ranking grup
/// tak, jak otagowano ćwiczenia, i ostrzeżenie o pominiętych mięśniach.
class StatsMusclesCard extends StatefulWidget {
  const StatsMusclesCard({super.key, required this.muscles});

  final MuscleDistribution muscles;

  @override
  State<StatsMusclesCard> createState() => _StatsMusclesCardState();
}

class _StatsMusclesCardState extends State<StatsMusclesCard> {
  static const _collapsedRows = 6;

  bool _expanded = false;
  MuscleGroup? _openMuscle;

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
                  'Serie na grupę mięśniową, tak jak otagowano ćwiczenia; '
                  'mięśnie wspomagające liczą się po połowie. „Główne” to '
                  'mięśnie, które były celem ćwiczeń; „wspomagające” tylko '
                  'pomagały. Te same reguły co na mapie sesji.',
                  style: _captionStyle,
                ),
                const SizedBox(height: AppSpacing.md),
                if (m.regions.isNotEmpty) ...[
                  const _SubHeader('PODZIAŁ NA PARTIE'),
                  const SizedBox(height: AppSpacing.sm),
                  _RegionDonut(
                    regions: m.regions,
                    totalSets: m.taggedSets > 0
                        ? m.taggedSets.toDouble()
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                const _SubHeader('MAPA OBCIĄŻENIA'),
                const SizedBox(height: AppSpacing.sm),
                _BodyMap(bodyRoles: m.bodyRoles),
                const SizedBox(height: AppSpacing.lg),
                const _SubHeader('RANKING MIĘŚNI'),
                const SizedBox(height: AppSpacing.xs),
                _MuscleRanking(
                  muscles: _expanded
                      ? m.muscles
                      : m.muscles.take(_collapsedRows).toList(),
                  leaderSets: m.muscles.first.sets,
                  leaderTargetSets: m.leaderTargetSets,
                  openMuscle: _openMuscle,
                  onToggle: (muscle) => setState(
                    () => _openMuscle = _openMuscle == muscle ? null : muscle,
                  ),
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
  const _RegionDonut({required this.regions, this.totalSets});

  final List<RegionStat> regions;

  /// Serie do napisu w środku; bez niej suma ważonych serii partii.
  final double? totalSets;

  static const _size = 120.0;

  @override
  Widget build(BuildContext context) {
    final total = totalSets ?? regions.fold<double>(0, (a, r) => a + r.sets);
    final percents = roundedPercents([for (final r in regions) r.share]);
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
              // Otwór koła ma ~84 px — tysiące serii albo duża czcionka
              // zmniejszają napis zamiast wychodzić na pierścień.
              SizedBox(
                width: 76,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
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
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, r) in regions.indexed)
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
                        formatStatsPercent(percents[i], nonZero: r.share > 0),
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
  const _BodyMap({required this.bodyRoles});

  /// Konkretne mięśnie → 0..1; grupy zbiorcze są już rozwinięte w domenie.
  final Map<MuscleGroup, MuscleRole> bodyRoles;

  static const _style = BodyHighlighterStyle.dark(
    highColor: exercisePrimaryMuscleColor,
    lowColor: exerciseSecondaryMuscleColor,
  );

  /// Dwie role, jak na mapie sesji: cel świeci mocno, wsparcie słabo. Mięśnie
  /// bez serii zostają szare.
  static const _primaryIntensity = 1.0;
  static const _secondaryIntensity = 0.3;

  /// Kilka mięśni trafia w ten sam obszar manekina (np. najszersze
  /// i romboidalne) — obszar świeci rolą ważniejszego z nich.
  Set<MuscleHighlight> _highlights() {
    final bySlug = <String, double>{};
    for (final entry in bodyRoles.entries) {
      final level = entry.value == MuscleRole.primary
          ? _primaryIntensity
          : _secondaryIntensity;
      final slug = entry.key.bodyHighlighterSlug;
      if (level > (bySlug[slug] ?? 0)) bySlug[slug] = level;
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
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xxs,
          children: [
            _LegendDot(color: _style.highColor, label: 'Główne'),
            _LegendDot(color: _style.lowColor, label: 'Wspomagające'),
            _LegendDot(
              color: _style.inactiveFill,
              label: 'Brak',
              outline: _style.outlineColor,
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label, this.outline});

  final Color color;
  final String label;
  final Color? outline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: outline == null ? null : Border.all(color: outline!),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: _captionStyle),
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
  const _MuscleRanking({
    required this.muscles,
    required this.leaderSets,
    required this.openMuscle,
    required this.onToggle,
    required this.leaderTargetSets,
  });

  final List<MuscleStat> muscles;
  final double leaderSets;
  final int leaderTargetSets;
  final MuscleGroup? openMuscle;
  final ValueChanged<MuscleGroup> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final m in muscles)
          _MuscleBar(
            stat: m,
            isOpen: m.muscle == openMuscle,
            onTap: () => onToggle(m.muscle),
            leaderTargetSets: leaderTargetSets,
            fill: leaderSets > 0 ? (m.sets / leaderSets).clamp(0, 1) : 0,
          ),
      ],
    );
  }
}

class _MuscleBar extends StatelessWidget {
  const _MuscleBar({
    required this.stat,
    required this.fill,
    required this.isOpen,
    required this.onTap,
    required this.leaderTargetSets,
  });

  final MuscleStat stat;
  final double fill;
  final bool isOpen;
  final VoidCallback onTap;
  final int leaderTargetSets;

  @override
  Widget build(BuildContext context) {
    final sets = formatStatsDecimal(stat.sets);
    final strong = stat.role == MuscleRole.primary;
    final region = stat.muscle.region;
    final color = region == null
        ? AppColors.primaryVariant
        : _regionColor(region);
    // Przy dużej czcionce znaczek roli nie mieści się obok liczby serii.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.15;
    final badge = _RoleBadge(strong: strong);
    return Column(
      children: [
        // Źródła są poza wykluczonym węzłem, żeby czytnik ekranu je widział.
        Semantics(
          container: true,
          button: true,
          expanded: isOpen,
          onTap: onTap,
          excludeSemantics: true,
          label:
              '${_rankLabel(stat.muscle)}: $sets ${_setsLabel(stat.sets)}, '
              '${strong ? 'główne' : 'wspomagające'}',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.sm),
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
                          _rankLabel(stat.muscle),
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
                      if (!stacked) ...[
                        const SizedBox(width: AppSpacing.xs),
                        badge,
                      ],
                    ],
                  ),
                  if (stacked)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: badge,
                      ),
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
          ),
        ),
        if (isOpen)
          _MuscleSources(stat: stat, leaderTargetSets: leaderTargetSets),
      ],
    );
  }
}

/// Skąd wzięły się serie mięśnia: ćwiczenia z okresu, od największego wkładu.
class _MuscleSources extends StatelessWidget {
  const _MuscleSources({required this.stat, required this.leaderTargetSets});

  final MuscleStat stat;
  final int leaderTargetSets;

  static const _maxRows = 6;

  @override
  Widget build(BuildContext context) {
    final shown = stat.sources.take(_maxRows).toList(growable: false);
    final rest = stat.sources.length - shown.length;
    final role = muscleRoleReason(
      role: stat.role,
      targetSets: stat.targetSets,
      leaderTargetSets: leaderTargetSets,
    );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(role, style: _captionStyle),
          const SizedBox(height: AppSpacing.xs),
          const _SubHeader('Z TYCH ĆWICZEŃ'),
          const SizedBox(height: 4),
          for (final source in shown) _SourceRow(source: source),
          if (rest > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '+$rest ${polishPlural(rest, 'kolejne ćwiczenie', 'kolejne ćwiczenia', 'kolejnych ćwiczeń')}',
                style: _captionStyle,
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'W rankingu: ${formatStatsDecimal(stat.sets)} '
            '${_setsLabel(stat.sets)} (cel liczy się za całą serię, '
            'wspomaganie za pół).',
            style: _captionStyle,
          ),
          if (stat.muscle.isCoarse)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Tag „${stat.muscle.label}” nie wskazuje konkretnego mięśnia, '
                'więc na sylwetce zapala cały region.',
                style: _captionStyle,
              ),
            ),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source});

  final MuscleSource source;

  @override
  Widget build(BuildContext context) {
    final role = source.isTarget
        ? 'cel'
        : source.isSupport
        ? 'wspomaga'
        : 'cel i wspomaga';
    final sets = polishPlural(source.sets, 'seria', 'serie', 'serii');
    final volume = source.volumeKg > 0
        ? ' · ${formatVolumeKg(source.volumeKg)}'
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      // Nazwa nad szczegółami: długi opis nie ściska się ani nie wylewa.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            source.exerciseName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '$role · ${source.sets} $sets$volume',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.strong});

  final bool strong;

  @override
  Widget build(BuildContext context) {
    final color = strong
        ? exercisePrimaryMuscleColor
        : exerciseSecondaryMuscleColor;
    return ConstrainedBox(
      // Stała szerokość wyrównuje kolumnę znaczków.
      constraints: const BoxConstraints(minWidth: 88),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: strong ? 0.2 : 0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          strong ? 'GŁÓWNE' : 'WSPOMAGAJĄCE',
          maxLines: 1,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: strong ? AppColors.primaryVariant : color,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
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
                const SizedBox(height: 2),
                // Tag „Nogi” czy „Plecy” obejmuje wszystkie mięśnie regionu,
                // więc nie ostrzegamy o mięśniach, które taka grupa pokrywa.
                const Text(
                  'Grupy zbiorcze (Nogi, Plecy, Barki) obejmują swoje mięśnie.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
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
