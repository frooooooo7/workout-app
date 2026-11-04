import 'dart:math' as math;

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

/// Etykieta pozycji rankingu: grupy zbiorcze pełną nazwą („Nogi”, „Plecy”,
/// „Barki”), granularne skróconą, żeby zmieściły się w wąskim wierszu.
String _rankLabel(MuscleGroup group) =>
    group.isCoarse ? group.label : group.shortLabel;

/// Mapa obciążenia: manekin przód/tył podświetlony rolami mięśni
/// ([MuscleDistribution.bodyRoles]) z legendą.
class StatsMuscleMapCard extends StatelessWidget {
  const StatsMuscleMapCard({super.key, required this.muscles});

  final MuscleDistribution muscles;

  @override
  Widget build(BuildContext context) {
    final m = muscles;
    return SessionSectionCard(
      child: m.isEmpty
          ? const _MutedNote(
              icon: Icons.accessibility_new_rounded,
              text: 'Dodaj partie mięśni do ćwiczeń, aby zobaczyć rozkład.',
            )
          : StatsBodyMap(
              bodyRoles: m.bodyRoles,
              neglected: m.neglected,
              figureHeight: 196,
              legend: true,
            ),
    );
  }
}

/// Serie na partię w przeliczeniu na tydzień, na tle pasa 10–20 serii, który
/// wystarcza większości osób. Partia bez serii świeci na bursztynowo.
class StatsRegionBarsCard extends StatelessWidget {
  const StatsRegionBarsCard({
    super.key,
    required this.muscles,
    required this.window,
    required this.rangeLabel,
  });

  final MuscleDistribution muscles;
  final StatsWindow window;

  /// „30 dni”, „3 mies.” — do podpisu „średnio z …”.
  final String rangeLabel;

  /// Granice pasa zalecanego, serii na partię w tygodniu.
  static const bandFrom = 10.0;
  static const bandTo = 20.0;

  @override
  Widget build(BuildContext context) {
    final m = muscles;
    if (m.isEmpty) return const SizedBox.shrink();
    // Okno krótsze niż tydzień liczymy jak tydzień — inaczej trzy dni
    // treningu wyglądałyby jak rekordowy tydzień.
    final weeks = math.max(1.0, window.days / 7);
    final rows = <_RegionRow>[
      for (final r in m.regions)
        _RegionRow(
          label: r.region.label,
          // Pasmo dotyczy jednej partii — region liczymy średnio na partię.
          perWeek: r.sets / weeks / r.muscleCount,
        ),
    ];
    final present = {for (final r in m.regions) r.region};
    for (final g in m.neglected) {
      final region = g.region;
      if (region != null && present.contains(region)) continue;
      if (rows.any((r) => r.neglected && r.label == _rankLabel(g))) continue;
      rows.add(_RegionRow(label: _rankLabel(g), perWeek: 0, neglected: true));
    }
    final top = rows.fold<double>(0, (a, r) => math.max(a, r.perWeek));
    final scale = math.max(bandTo + 4, top * 1.05);

    return SessionSectionCard(
      title: 'Serie w tygodniu',
      trailing: Text(
        'średnio z $rangeLabel',
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in rows) _RegionBarRow(row: row, scale: scale),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '10–20 serii / tydz. na partię wystarcza większości osób',
                  style: _captionStyle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RegionRow {
  const _RegionRow({
    required this.label,
    required this.perWeek,
    this.neglected = false,
  });

  final String label;
  final double perWeek;
  final bool neglected;
}

class _RegionBarRow extends StatelessWidget {
  const _RegionBarRow({required this.row, required this.scale});

  final _RegionRow row;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final value = row.perWeek;
    final text = formatStatsDecimal(value, digits: value < 10 ? 1 : 0);
    final color = row.neglected ? AppColors.statAmber : AppColors.primary;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '${row.label}: $text serii w tygodniu',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 74,
              child: Text(
                row.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: row.neglected
                      ? AppColors.statAmber
                      : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  return SizedBox(
                    height: 16,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.chartTrack,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Positioned(
                          left: w * StatsRegionBarsCard.bandFrom / scale,
                          width:
                              w *
                              (StatsRegionBarsCard.bandTo -
                                  StatsRegionBarsCard.bandFrom) /
                              scale,
                          top: 0,
                          bottom: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: AppColors.success.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                        if (value > 0)
                          TweenAnimationBuilder<double>(
                            tween: Tween(
                              begin: 0,
                              end: (value / scale).clamp(0, 1),
                            ),
                            duration: const Duration(milliseconds: 520),
                            curve: Curves.easeOutCubic,
                            builder: (context, f, _) => Container(
                              width: w * f,
                              height: 6,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 74,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: text,
                      style: TextStyle(
                        color: row.neglected
                            ? AppColors.statAmber
                            : AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const TextSpan(
                      text: ' / tydz.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.right,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ranking mięśni z rozwijanymi źródłami serii. Zasady liczenia są pod
/// ikonką (i), nie w czterech linijkach nad rankingiem.
class StatsMuscleRankingCard extends StatefulWidget {
  const StatsMuscleRankingCard({super.key, required this.muscles});

  final MuscleDistribution muscles;

  @override
  State<StatsMuscleRankingCard> createState() => _StatsMuscleRankingCardState();
}

class _StatsMuscleRankingCardState extends State<StatsMuscleRankingCard> {
  static const _collapsedRows = 6;

  bool _expanded = false;
  MuscleGroup? _openMuscle;

  void _showInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Jak liczymy serie'),
        content: const Text(
          'Serie na grupę mięśniową, tak jak otagowano ćwiczenia. Mięsień '
          'wspomagający liczy się po połowie serii. „Główne” to mięśnie, '
          'które były celem ćwiczeń, „wspomagające” tylko pomagały — te same '
          'reguły co na mapie sesji.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Rozumiem'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.muscles;
    if (m.isEmpty) return const SizedBox.shrink();
    return SessionSectionCard(
      title: 'Ranking mięśni',
      trailing: IconButton(
        key: const ValueKey('stats-muscles-info'),
        tooltip: 'Jak liczymy serie',
        onPressed: _showInfo,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 32, height: 28),
        icon: const Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: AppColors.textMuted,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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

/// Manekin przód/tył podświetlony rolami mięśni; pominięte partie świecą na
/// bursztynowo. [figureHeight] pozwala zmniejszyć go na pulpicie.
class StatsBodyMap extends StatelessWidget {
  const StatsBodyMap({
    super.key,
    required this.bodyRoles,
    this.neglected = const [],
    this.figureHeight = 196,
    this.legend = false,
  });

  /// Konkretne mięśnie → rola; grupy zbiorcze są już rozwinięte w domenie.
  final Map<MuscleGroup, MuscleRole> bodyRoles;

  /// Kluczowe mięśnie bez serii — pokazane jako „pominięte”.
  final List<MuscleGroup> neglected;
  final double figureHeight;

  /// Legenda pod mapą i podpisy „Przód”/„Tył”.
  final bool legend;

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
      for (final g in neglected)
        if (!bySlug.containsKey(g.bodyHighlighterSlug))
          MuscleHighlight(
            muscle: g.bodyHighlighterSlug,
            intensity: intensityToMuscleIntensity(_primaryIntensity),
            customColor: AppColors.statAmber,
          ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final highlights = _highlights();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Figure(
              view: bh.BodyView.front,
              label: legend ? 'Przód' : null,
              height: figureHeight,
              highlights: highlights,
            ),
            SizedBox(width: legend ? AppSpacing.lg : AppSpacing.xs),
            _Figure(
              view: bh.BodyView.back,
              label: legend ? 'Tył' : null,
              height: figureHeight,
              highlights: highlights,
            ),
          ],
        ),
        if (legend) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xxs,
            children: [
              _LegendDot(color: _style.highColor, label: 'Cel ćwiczeń'),
              _LegendDot(color: _style.lowColor, label: 'Pomagały'),
              if (neglected.isNotEmpty)
                const _LegendDot(
                  color: AppColors.statAmber,
                  label: 'Pominięte',
                ),
              _LegendDot(
                color: _style.inactiveFill,
                label: 'Brak',
                outline: _style.outlineColor,
              ),
            ],
          ),
        ],
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
    required this.height,
    required this.highlights,
  });

  final bh.BodyView view;
  final String? label;
  final double height;
  final Set<MuscleHighlight> highlights;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: height * 88 / 196,
          height: height,
          child: MuscleBodyHighlighter(
            view: view,
            highlights: highlights,
            style: StatsBodyMap._style,
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(
            label!,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
    const color = AppColors.primaryVariant;
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
