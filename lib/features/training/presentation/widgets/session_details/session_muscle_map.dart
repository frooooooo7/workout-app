import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../body_highlighter/adapters/muscle_group_adapter.dart';
import '../../../../body_highlighter/models/body_highlighter_style.dart';
import '../../../../body_highlighter/models/body_view.dart' as bh_view;
import '../../../../body_highlighter/widgets/muscle_body_highlighter.dart';
import '../../../../library/domain/models/exercise.dart';
import '../../../domain/models/training_history_models.dart';
import 'body_muscle_paths.dart';
import 'muscle_load.dart';
import 'session_details_formatters.dart';
import 'session_section_card.dart';

/// Sekcja „mapa mięśni": manekin z przodu i z tyłu z podświetlonymi partiami,
/// obok ranking najmocniej obciążonych mięśni.
///
/// Nie powtarza metryk sesji (czas, serie, objętość) — te żyją wyłącznie
/// w nagłówku ekranu. Tutaj liczy się wyłącznie rozkład obciążenia.
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
  MuscleGroup? _selected;

  @override
  void initState() {
    super.initState();
    _loads = computeMuscleLoads(widget.detail);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )..forward();
  }

  @override
  void didUpdateWidget(SessionMuscleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail != widget.detail) {
      _loads = computeMuscleLoads(widget.detail);
      _selected = null;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Map<MuscleGroup, double> get _intensityByMuscle => {
    for (final load in _loads) load.muscle: load.intensity,
  };

  void _toggleSelection(MuscleGroup? muscle) {
    setState(() => _selected = _selected == muscle ? null : muscle);
  }

  void _showMethodologyDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Jak liczymy procenty',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _MethodologyPoint(
                title: 'Ranking i procenty',
                body:
                    'Pokazany % to udział danego mięśnia w łącznej objętości '
                    'tej sesji (ciężar × powtórzenia × serie). Wszystkie '
                    'wartości sumują się do 100% — to odpowiedź na pytanie '
                    '„jak rozłożyła się dzisiejsza praca między partie".',
              ),
              SizedBox(height: 12),
              _MethodologyPoint(
                title: 'Podświetlenie na manekinie',
                body:
                    'Kolor na sylwetce liczony jest inaczej: względem '
                    'najmocniej obciążonego mięśnia sesji, który zawsze '
                    'świeci najintensywniej. Dzięki temu mapa czytelnie '
                    'pokazuje, gdzie był największy nacisk, nawet jeśli '
                    'trenowałeś wiele partii naraz.',
              ),
              SizedBox(height: 12),
              _MethodologyPoint(
                title: 'Ćwiczenia wielostawowe',
                body:
                    'Pierwszy mięsień z listy ćwiczenia liczony jest jako '
                    'główny (pełna objętość), kolejne jako wspomagające '
                    '(połowa objętości) — inaczej przysiad ważyłby tyle '
                    'samo dla nóg, co przysiad dla pleców.',
              ),
              SizedBox(height: 12),
              _MethodologyPoint(
                title: 'Trening bez ciężaru',
                body:
                    'Jeśli sesja nie ma zalogowanych kilogramów (np. trening '
                    'na masie własnej), zamiast objętości liczymy udział '
                    'liczby ukończonych serii.',
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

    final intensities = _intensityByMuscle;
    final selectedLoad = _selected == null
        ? null
        : _loads.firstWhere(
            (l) => l.muscle == _selected,
            orElse: () => _loads.first,
          );

    return SessionSectionCard(
      icon: Icons.accessibility_new_rounded,
      title: 'Mapa mięśni',
      trailing: _InfoButton(onTap: () => _showMethodologyDialog(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final figures = AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final view in BodyView.values) ...[
                      _BodyFigure(
                        view: view,
                        intensities: intensities,
                        selected: _selected,
                        progress: _controller.value,
                        onMuscleTap: _toggleSelection,
                      ),
                      if (view != BodyView.values.last)
                        const SizedBox(width: 6),
                    ],
                  ],
                ),
              );

              final ranking = _MuscleRanking(
                loads: _loads,
                selected: _selected,
                onSelect: _toggleSelection,
              );

              // Poniżej ~330 px ranking obok manekinów robi się nieczytelny,
              // więc ląduje pod nimi.
              if (constraints.maxWidth < 330) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: figures),
                    const SizedBox(height: 16),
                    ranking,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  figures,
                  const SizedBox(width: 16),
                  Expanded(child: ranking),
                ],
              );
            },
          ),
          if (selectedLoad != null) ...[
            const SizedBox(height: 14),
            _SelectedMuscleDetail(load: selectedLoad),
          ],
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
      label: 'Jak liczymy procenty obciążenia',
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
    required this.intensities,
    required this.selected,
    required this.progress,
    required this.onMuscleTap,
  });

  final BodyView view;
  final Map<MuscleGroup, double> intensities;
  final MuscleGroup? selected;
  final double progress;
  final ValueChanged<MuscleGroup?> onMuscleTap;

  @override
  Widget build(BuildContext context) {
    final highlights = toMuscleHighlights(intensities);
    final bhView =
        view == BodyView.front ? bh_view.BodyView.front : bh_view.BodyView.back;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 90,
          height: 202,
          child: MuscleBodyHighlighter(
            view: bhView,
            highlights: highlights,
            style: const BodyHighlighterStyle.dark(),
            onMuscleTap: (region) {
              final matchedGroup = MuscleGroup.values
                  .where((g) => g.bodyHighlighterSlug == region.slug)
                  .firstOrNull;
              onMuscleTap(matchedGroup);
            },
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



class _MuscleRanking extends StatelessWidget {
  const _MuscleRanking({
    required this.loads,
    required this.selected,
    required this.onSelect,
  });

  final List<MuscleLoad> loads;
  final MuscleGroup? selected;
  final ValueChanged<MuscleGroup?> onSelect;

  static const _maxRows = 5;

  @override
  Widget build(BuildContext context) {
    final visible = loads.take(_maxRows).toList(growable: false);
    final rest = loads.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NAJMOCNIEJ OBCIĄŻONE',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 10),
        for (final load in visible)
          _MuscleBar(
            load: load,
            isSelected: load.muscle == selected,
            onTap: () => onSelect(load.muscle),
          ),
        if (rest > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+$rest ${_moreLabel(rest)}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  static String _moreLabel(int count) {
    if (count == 1) return 'kolejny mięsień';
    final lastDigit = count % 10;
    final lastTwo = count % 100;
    final isFew =
        lastDigit >= 2 && lastDigit <= 4 && !(lastTwo >= 12 && lastTwo <= 14);
    return isFew ? 'kolejne mięśnie' : 'kolejnych mięśni';
  }
}

class _MuscleBar extends StatelessWidget {
  const _MuscleBar({
    required this.load,
    required this.isSelected,
    required this.onTap,
  });

  final MuscleLoad load;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${load.muscle.label}, ${load.percent} procent obciążenia',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      load.muscle.shortLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${load.percent}%',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: load.share),
                  duration: const Duration(milliseconds: 620),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 5,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation(
                      isSelected ? Colors.white : AppColors.primaryVariant,
                    ),
                  ),
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
  const _SelectedMuscleDetail({required this.load});

  final MuscleLoad load;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      '${load.sets} ${_setsLabel(load.sets)}',
      if (load.volumeKg > 0) formatVolumeKg(load.volumeKg),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
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
            '${load.percent}%',
            style: const TextStyle(
              color: AppColors.primaryVariant,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  static String _setsLabel(int count) {
    if (count == 1) return 'seria';
    final lastDigit = count % 10;
    final lastTwo = count % 100;
    final isFew =
        lastDigit >= 2 && lastDigit <= 4 && !(lastTwo >= 12 && lastTwo <= 14);
    return isFew ? 'serie' : 'serii';
  }
}

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
