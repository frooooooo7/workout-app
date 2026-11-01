import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../../body_highlighter/adapters/muscle_group_adapter.dart';
import '../../../../body_highlighter/models/body_highlighter_style.dart';
import '../../../../body_highlighter/models/body_view.dart' as bh_view;
import '../../../../body_highlighter/models/muscle_highlight.dart';
import '../../../../body_highlighter/widgets/muscle_body_highlighter.dart';
import '../../../../library/domain/models/exercise.dart';
import '../../../../library/presentation/widgets/exercise_details/exercise_muscle_map.dart'
    show exercisePrimaryMuscleColor, exerciseSecondaryMuscleColor;
import '../../../domain/models/training_history_models.dart';
import '../../../domain/models/training_stats.dart' show MuscleSource;
import '../../../domain/services/muscle_roles.dart' show muscleRoleReason;
import 'body_muscle_paths.dart';
import 'muscle_load.dart';
import 'session_details_formatters.dart';
import 'session_section_card.dart';

/// Te same kolory co na ekranie szczegółów ćwiczenia: główne świecą niebieskim
/// akcentem aplikacji, wspomagające jaśniejszym błękitem.
const _mapStyle = BodyHighlighterStyle.dark(
  highColor: exercisePrimaryMuscleColor,
  lowColor: exerciseSecondaryMuscleColor,
);

const double _primaryIntensity = 1.0;
const double _secondaryIntensity = 0.3;

/// Podświetlenie manekina: główne na pełnej intensywności, wspomagające
/// słabiej. Grupa zbiorcza zapala cały swój region; gdy dwa tagi trafiają
/// w ten sam obszar, wygrywa ważniejsza rola.
@visibleForTesting
Set<MuscleHighlight> highlightsForLoads(List<MuscleLoad> loads) {
  final intensities = <MuscleGroup, double>{};
  for (final load in loads) {
    final intensity = load.isPrimary ? _primaryIntensity : _secondaryIntensity;
    for (final muscle in load.muscle.expanded) {
      final current = intensities[muscle] ?? 0;
      if (intensity > current) intensities[muscle] = intensity;
    }
  }
  // Kilka mięśni trafia w ten sam obszar manekina (np. najszersze
  // i romboidalne) — obszar dostaje najwyższą intensywność z nich.
  final bySlug = <String, double>{};
  for (final entry in intensities.entries) {
    final slug = entry.key.bodyHighlighterSlug;
    if (entry.value > (bySlug[slug] ?? 0)) bySlug[slug] = entry.value;
  }
  return {
    for (final e in bySlug.entries)
      MuscleHighlight(
        muscle: e.key,
        intensity: intensityToMuscleIntensity(e.value),
      ),
  };
}

/// Sekcja „mapa mięśni": manekin z przodu i z tyłu, na którym główne partie
/// świecą mocniej niż wspomagające, a pod nim obie grupy z liczbą serii.
///
/// Bez procentów: tagi ćwiczeń są grube (plecy, nogi, barki), więc udział
/// procentowy rozkładał się po równo i nic nie mówił. Nie powtarza też metryk
/// sesji (czas, serie, objętość) — te żyją w nagłówku ekranu.
class SessionMuscleMap extends StatefulWidget {
  const SessionMuscleMap({super.key, required this.detail});

  final TrainingSessionDetail detail;

  @override
  State<SessionMuscleMap> createState() => _SessionMuscleMapState();
}

class _SessionMuscleMapState extends State<SessionMuscleMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<MuscleLoad> _loads;
  late Set<MuscleHighlight> _highlights;
  MuscleGroup? _selected;

  @override
  void initState() {
    super.initState();
    _recomputeLoads();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )..forward();
  }

  @override
  void didUpdateWidget(SessionMuscleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail != widget.detail) {
      _recomputeLoads();
      _selected = null;
      _controller.forward(from: 0);
    }
  }

  void _recomputeLoads() {
    _loads = computeMuscleLoads(widget.detail);
    _highlights = highlightsForLoads(_loads);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleSelection(MuscleGroup? muscle) {
    setState(() => _selected = _selected == muscle ? null : muscle);
  }

  /// Dotknięcie obszaru manekina wybiera grupę, która go zapala (główne mają
  /// pierwszeństwo — lista jest posortowana).
  void _selectBySlug(String slug) {
    final match = _loads
        .where(
          (l) => l.muscle.expanded.any((m) => m.bodyHighlighterSlug == slug),
        )
        .firstOrNull;
    if (match != null) _toggleSelection(match.muscle);
  }

  void _showMethodologyDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Jak to liczymy',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _MethodologyPoint(
                title: 'Główne i wspomagające',
                body:
                    'Pierwszy mięsień z listy ćwiczenia to jego cel, kolejne '
                    'tylko pomagają. Mięsień jest „główny”, gdy był celem '
                    'w którymś ćwiczeniu i w co najmniej ćwierci tylu serii '
                    'co mięsień, który był celem najczęściej. Reszta jest '
                    'wspomagająca. Ćwiczenia na czas (kardio, deska) tylko '
                    'wspomagają, o ile w treningu są też serie na powtórzenia.',
              ),
              SizedBox(height: 12),
              _MethodologyPoint(
                title: 'Dlaczego bez procentów',
                body:
                    'Ćwiczenia mają przypisane grube grupy (plecy, nogi, '
                    'barki), więc procentowy podział wychodził niemal równy '
                    'i nic nie mówił. Pokazujemy rolę i liczbę serii.',
              ),
              SizedBox(height: 12),
              _MethodologyPoint(
                title: 'Grupy zbiorcze',
                body:
                    'Tag „Plecy”, „Nogi” czy „Barki” nie mówi, który mięsień '
                    'pracował, więc na sylwetce zapala cały region.',
              ),
              SizedBox(height: 12),
              _MethodologyPoint(
                title: 'Serie i objętość',
                body:
                    'Serie to ukończone serie ćwiczeń z tym mięśniem. '
                    'Objętość to ciężar × powtórzenia tych ćwiczeń; mięśnie '
                    'dzielące ćwiczenie liczą ją w całości, więc nie sumuj '
                    'jej między mięśniami.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Rozumiem',
              style: TextStyle(color: AppColors.primaryVariant),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loads.isEmpty) return const _MuscleMapEmpty();

    final primary = _loads.where((l) => l.isPrimary).toList(growable: false);
    final secondary = _loads.where((l) => !l.isPrimary).toList(growable: false);
    final selectedLoad = _selected == null
        ? null
        : _loads.where((l) => l.muscle == _selected).firstOrNull;

    return SessionSectionCard(
      icon: Icons.accessibility_new_rounded,
      title: 'Mapa mięśni',
      trailing: _InfoButton(onTap: () => _showMethodologyDialog(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: FadeTransition(
              opacity: _controller,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final view in BodyView.values) ...[
                    _BodyFigure(
                      view: view,
                      highlights: _highlights,
                      onMuscleTap: _selectBySlug,
                    ),
                    if (view != BodyView.values.last) const SizedBox(width: 12),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _MapLegend(),
          if (primary.isNotEmpty) ...[
            const SizedBox(height: 14),
            _MuscleGroupSection(
              title: 'GŁÓWNE',
              loads: primary,
              selected: _selected,
              onSelect: _toggleSelection,
            ),
          ],
          if (secondary.isNotEmpty) ...[
            const SizedBox(height: 14),
            _MuscleGroupSection(
              title: 'WSPOMAGAJĄCE',
              loads: secondary,
              selected: _selected,
              onSelect: _toggleSelection,
            ),
          ],
          const SizedBox(height: 12),
          if (selectedLoad != null)
            _SelectedMuscleDetail(
              load: selectedLoad,
              leaderPrimarySets: _loads.fold<int>(
                0,
                (a, l) => l.primarySets > a ? l.primarySets : a,
              ),
            )
          else
            const Text(
              'Dotknij mięśnia, żeby zobaczyć, z jakich ćwiczeń się wziął.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoButton extends StatelessWidget {
  const _InfoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Jak liczymy główne i wspomagające mięśnie',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _MethodologyPoint extends StatelessWidget {
  const _MethodologyPoint({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          body,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _BodyFigure extends StatelessWidget {
  const _BodyFigure({
    required this.view,
    required this.highlights,
    required this.onMuscleTap,
  });

  final BodyView view;
  final Set<MuscleHighlight> highlights;
  final ValueChanged<String> onMuscleTap;

  @override
  Widget build(BuildContext context) {
    final bhView = view == BodyView.front
        ? bh_view.BodyView.front
        : bh_view.BodyView.back;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 100,
          height: 224,
          child: MuscleBodyHighlighter(
            view: bhView,
            highlights: highlights,
            style: _mapStyle,
            onMuscleTap: (region) => onMuscleTap(region.slug),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          view.label,
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

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(color: exercisePrimaryMuscleColor, label: 'Główne'),
        SizedBox(width: 18),
        _LegendDot(color: exerciseSecondaryMuscleColor, label: 'Wspomagające'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

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
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MuscleGroupSection extends StatelessWidget {
  const _MuscleGroupSection({
    required this.title,
    required this.loads,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final List<MuscleLoad> loads;
  final MuscleGroup? selected;
  final ValueChanged<MuscleGroup?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final load in loads)
              _MuscleChip(
                load: load,
                isSelected: load.muscle == selected,
                onTap: () => onSelect(load.muscle),
              ),
          ],
        ),
      ],
    );
  }
}

class _MuscleChip extends StatelessWidget {
  const _MuscleChip({
    required this.load,
    required this.isSelected,
    required this.onTap,
  });

  final MuscleLoad load;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = load.isPrimary
        ? exercisePrimaryMuscleColor
        : exerciseSecondaryMuscleColor;
    final role = load.isPrimary ? 'główny' : 'wspomagający';
    final sets = '${load.sets} ${_setsLabel(load.sets)}';
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${load.muscle.label}, $role, $sets',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: load.isPrimary ? 0.16 : 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.white : accent.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                load.muscle.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                sets,
                style: TextStyle(
                  color: load.isPrimary
                      ? AppColors.primaryVariant
                      : exerciseSecondaryMuscleColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedMuscleDetail extends StatelessWidget {
  const _SelectedMuscleDetail({
    required this.load,
    required this.leaderPrimarySets,
  });

  final MuscleLoad load;
  final int leaderPrimarySets;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      '${load.sets} ${_setsLabel(load.sets)}',
      if (load.volumeKg > 0) formatVolumeKg(load.volumeKg),
    ];
    final accent = load.isPrimary
        ? AppColors.primaryVariant
        : exerciseSecondaryMuscleColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      load.muscle.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      parts.join('  ·  '),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                load.isPrimary ? 'Główny' : 'Wspomagający',
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            muscleRoleReason(
              role: load.role,
              targetSets: load.primarySets,
              leaderTargetSets: leaderPrimarySets,
            ),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Z TYCH ĆWICZEŃ',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 4),
          for (final source in load.sources) _SourceRow(source: source),
          if (load.muscle.isCoarse) ...[
            const SizedBox(height: 8),
            Text(
              'Ćwiczenia mają tag „${load.muscle.label}”, który nie wskazuje '
              'konkretnego mięśnia, więc sylwetka zapala cały region: '
              '${load.muscle.expanded.map((m) => m.shortLabel).join(', ')}.',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ],
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
    final detail = [
      role,
      '${source.sets} ${_setsLabel(source.sets)}',
      if (source.volumeKg > 0) formatVolumeKg(source.volumeKg),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              source.exerciseName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            detail,
            textAlign: TextAlign.right,
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

String _setsLabel(int count) => polishPlural(count, 'seria', 'serie', 'serii');

class _MuscleMapEmpty extends StatelessWidget {
  const _MuscleMapEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.accessibility_new_rounded,
            color: AppColors.textMuted,
            size: 26,
          ),
          SizedBox(height: 10),
          Text(
            'Brak ukończonych serii — nie ma czego nanieść na mapę mięśni.',
            textAlign: TextAlign.center,
            style: TextStyle(
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
