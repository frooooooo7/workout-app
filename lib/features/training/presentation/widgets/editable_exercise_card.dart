import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/units/weight_unit.dart';
import '../../../library/data/exercise_image_uri.dart';
import '../../../library/domain/models/exercise_tracking.dart';
import '../../domain/models/custom_training_plan.dart';
import 'table_cell_input.dart';

/// Miejsce karty w superserii — karty jednej grupy łączą się w jeden blok.
enum SupersetSegment { none, first, middle, last }

class EditableExerciseCard extends StatefulWidget {
  const EditableExerciseCard({
    super.key,
    required this.index,
    required this.planExercise,
    required this.onChanged,
    required this.onRemove,
    this.restChip,
    this.supersetLabel,
    this.segment = SupersetSegment.none,
    this.header,
    this.footer,
    this.bottomMargin,
  });

  final int index;
  final PlanExercise planExercise;
  final ValueChanged<PlanExercise> onChanged;
  final VoidCallback onRemove;

  /// Przerwa ćwiczenia (w superserii tylko przy ostatnim, w [footer]).
  final Widget? restChip;

  /// „A1”, „A2” — miejsce w superserii.
  final String? supersetLabel;
  final SupersetSegment segment;

  /// Nagłówek grupy nad pierwszym ćwiczeniem superserii.
  final Widget? header;

  /// Stopka pod ostatnim ćwiczeniem superserii („Przerwa po rundzie”).
  final Widget? footer;

  /// Odstęp pod kartą; domyślnie 12 (0 wewnątrz superserii).
  final double? bottomMargin;

  @override
  State<EditableExerciseCard> createState() => _EditableExerciseCardState();
}

class _EditableExerciseCardState extends State<EditableExerciseCard> {
  final ExpansibleController _controller = ExpansibleController();
  late PlanExercise _draft;
  DecorationImage? _thumb;
  String? _thumbUrl;

  @override
  void initState() {
    super.initState();
    _draft = widget.planExercise;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cacheThumb();
  }

  @override
  void didUpdateWidget(covariant EditableExerciseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.planExercise.id != widget.planExercise.id) {
      _draft = widget.planExercise;
      _thumb = null;
      _cacheThumb();
    } else if (oldWidget.planExercise.isExpanded !=
        widget.planExercise.isExpanded) {
      _draft = _draft.copyWith(isExpanded: widget.planExercise.isExpanded);
      if (widget.planExercise.isExpanded) {
        if (!_controller.isExpanded) _controller.expand();
      } else {
        if (_controller.isExpanded) _controller.collapse();
      }
    } else if (oldWidget.planExercise.sets.length !=
        widget.planExercise.sets.length) {
      _draft = widget.planExercise;
    }
    // Przerwę i superserię zmienia ekran planu — szkic karty nie może ich
    // nadpisać przy następnej edycji serii.
    final next = widget.planExercise;
    if (_draft.restSeconds != next.restSeconds ||
        _draft.supersetGroup != next.supersetGroup) {
      _draft = _draft.copyWith(
        restSeconds: next.restSeconds,
        clearRestSeconds: next.restSeconds == null,
        supersetGroup: next.supersetGroup,
        clearSupersetGroup: next.supersetGroup == null,
      );
    }
  }

  void _cacheThumb() {
    final url = _draft.exercise.imageUrl;
    if (_thumb != null && _thumbUrl == url) return;
    _thumbUrl = url;
    final provider = exerciseThumbProvider(context, url, logicalSize: 40);
    _thumb = provider == null
        ? null
        : DecorationImage(
            image: provider,
            fit: BoxFit.cover,
            onError: (_, _) {},
          );
  }

  void _commit(PlanExercise next) {
    setState(() => _draft = next);
    // Lista w rodzicu aktualizuje się od razu i tanio (rodzic woła setState
    // tylko przy zmianie liczby serii), żeby „Zapisz” nie zgubił ostatnich
    // znaków.
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final planExercise = _draft;
    final tracking = planExercise.exercise.tracking;
    final distanceUnit = planExercise.exercise.distanceUnit;
    final cardio = tracking.tracksDuration;
    final hasRir = !cardio && planExercise.sets.any((s) => s.rir != null);
    final hasTempo = !cardio && planExercise.sets.any((s) => s.tempo != null);
    final segment = widget.segment;
    final grouped = segment != SupersetSegment.none;
    final roundTop =
        segment == SupersetSegment.none || segment == SupersetSegment.first;
    final roundBottom =
        segment == SupersetSegment.none || segment == SupersetSegment.last;
    const radius = Radius.circular(20);

    final tile = ExpansionTile(
      controller: _controller,
      tilePadding: EdgeInsets.fromLTRB(grouped ? 24 : 16, 8, 16, 8),
      childrenPadding: EdgeInsets.fromLTRB(grouped ? 24 : 16, 0, 16, 16),
      initiallyExpanded: planExercise.isExpanded,
      shape: const Border(),
      collapsedShape: const Border(),
      onExpansionChanged: (expanded) {
        _commit(planExercise.copyWith(isExpanded: expanded));
      },
      title: Row(
        children: [
          if (widget.supersetLabel != null)
            SizedBox(
              width: 30,
              child: Text(
                widget.supersetLabel!,
                style: const TextStyle(
                  color: AppColors.superset,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              image: _thumb,
            ),
            child: planExercise.exercise.imageUrl == null
                ? Icon(
                    cardio
                        ? Icons.directions_run_rounded
                        : Icons.fitness_center,
                    color: AppColors.textMuted,
                    size: 24,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  planExercise.exercise.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cardio
                      ? cardioSegmentsLabel(planExercise.sets.length)
                      : '${planExercise.sets.length} serii',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (widget.restChip != null) ...[
            const SizedBox(width: 8),
            widget.restChip!,
            const SizedBox(width: 4),
          ],
          IconButton(
            onPressed: widget.onRemove,
            icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      iconColor: Colors.white,
      collapsedIconColor: AppColors.textMuted,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  cardio ? 'ODC.' : 'SERIA',
                  textAlign: TextAlign.center,
                  style: _headerStyle,
                ),
              ),
              if (tracking.tracksWeight) ...const [
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'CIĘŻAR',
                    textAlign: TextAlign.center,
                    style: _headerStyle,
                  ),
                ),
              ],
              if (tracking.tracksReps) ...const [
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'POWT.',
                    textAlign: TextAlign.center,
                    style: _headerStyle,
                  ),
                ),
              ],
              if (cardio) ...const [
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'CEL: CZAS',
                    textAlign: TextAlign.center,
                    style: _headerStyle,
                  ),
                ),
              ],
              if (tracking.tracksDistance) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'DYSTANS (${distanceUnit.label})',
                    textAlign: TextAlign.center,
                    style: _headerStyle,
                  ),
                ),
              ],
              if (hasRir) ...const [
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'RIR',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
              if (hasTempo) ...const [
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'TEMPO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 32),
            ],
          ),
        ),
        ...planExercise.sets.asMap().entries.map((entry) {
          final setIndex = entry.key;
          final set = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    '${setIndex + 1}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (tracking.tracksWeight) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: WeightCellInput(
                      fallbackHint: '-',
                      valueKg: set.weight,
                      suffixText: ' ${WeightUnits.current.label}',
                      onChanged: (val) {
                        final newSets = List<ExerciseSet>.from(
                          planExercise.sets,
                        );
                        newSets[setIndex] = set.copyWith(
                          weight: val.isEmpty ? null : val,
                          clearWeight: val.isEmpty,
                        );
                        _commit(planExercise.copyWith(sets: newSets));
                      },
                    ),
                  ),
                ],
                if (tracking.tracksReps) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: TableCellInput(
                      hint: '-',
                      value: set.reps,
                      onChanged: (val) {
                        final newSets = List<ExerciseSet>.from(
                          planExercise.sets,
                        );
                        newSets[setIndex] = set.copyWith(reps: val);
                        _commit(planExercise.copyWith(sets: newSets));
                      },
                    ),
                  ),
                ],
                if (cardio) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: DurationCellInput(
                      key: ValueKey('plan-set-duration-$setIndex'),
                      seconds: set.durationSeconds,
                      onChanged: (seconds) {
                        final newSets = List<ExerciseSet>.from(
                          planExercise.sets,
                        );
                        newSets[setIndex] = set.copyWith(
                          durationSeconds: seconds,
                          clearDuration: seconds == null,
                        );
                        _commit(planExercise.copyWith(sets: newSets));
                      },
                    ),
                  ),
                ],
                if (tracking.tracksDistance) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: DistanceCellInput(
                      key: ValueKey('plan-set-distance-$setIndex'),
                      meters: set.distanceM,
                      unit: distanceUnit,
                      onChanged: (meters) {
                        final newSets = List<ExerciseSet>.from(
                          planExercise.sets,
                        );
                        newSets[setIndex] = set.copyWith(
                          distanceM: meters,
                          clearDistance: meters == null,
                        );
                        _commit(planExercise.copyWith(sets: newSets));
                      },
                    ),
                  ),
                ],
                if (hasRir) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: TableCellInput(
                      hint: '-',
                      value: set.rir ?? '',
                      onChanged: (val) {
                        final newSets = List<ExerciseSet>.from(
                          planExercise.sets,
                        );
                        newSets[setIndex] = set.copyWith(rir: val);
                        _commit(planExercise.copyWith(sets: newSets));
                      },
                    ),
                  ),
                ],
                if (hasTempo) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: TableCellInput(
                      hint: '-',
                      value: set.tempo ?? '',
                      onChanged: (val) {
                        final newSets = List<ExerciseSet>.from(
                          planExercise.sets,
                        );
                        newSets[setIndex] = set.copyWith(tempo: val);
                        _commit(planExercise.copyWith(sets: newSets));
                      },
                    ),
                  ),
                ],
                SizedBox(
                  width: 32,
                  child: IconButton(
                    onPressed: () {
                      final newSets = List<ExerciseSet>.from(planExercise.sets);
                      newSets.removeAt(setIndex);
                      _commit(planExercise.copyWith(sets: newSets));
                    },
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                final newSets = List<ExerciseSet>.from(planExercise.sets);
                final previous = newSets.isNotEmpty ? newSets.last : null;
                newSets.add(
                  ExerciseSet(
                    weight: previous?.weight,
                    reps: previous?.reps ?? '',
                    rir: previous?.rir,
                    tempo: previous?.tempo,
                    durationSeconds: previous?.durationSeconds,
                    distanceM: previous?.distanceM,
                  ),
                );
                _commit(planExercise.copyWith(sets: newSets));
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(cardio ? 'Dodaj odcinek' : 'Dodaj serię'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
            const Spacer(),
            if (!hasRir && !cardio)
              TextButton(
                onPressed: () {
                  final newSets = planExercise.sets
                      .map((s) => s.copyWith(rir: ''))
                      .toList();
                  _commit(planExercise.copyWith(sets: newSets));
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('+ RIR', style: TextStyle(fontSize: 12)),
              ),
            if (!hasTempo && !cardio)
              TextButton(
                onPressed: () {
                  final newSets = planExercise.sets
                      .map((s) => s.copyWith(tempo: ''))
                      .toList();
                  _commit(planExercise.copyWith(sets: newSets));
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('+ Tempo', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ],
    );

    return Container(
      margin: EdgeInsets.only(
        bottom: widget.bottomMargin ?? (roundBottom ? 12 : 0),
      ),
      decoration: BoxDecoration(
        color: grouped ? _groupColor : AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: roundTop ? radius : Radius.zero,
          bottom: roundBottom ? radius : Radius.zero,
        ),
        border: grouped ? null : Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.header != null) widget.header!,
              tile,
              if (widget.footer != null) widget.footer!,
            ],
          ),
          if (grouped)
            Positioned(
              left: 12,
              width: 3,
              top: segment == SupersetSegment.first ? 52 : 0,
              bottom: segment == SupersetSegment.last ? 64 : 0,
              child: const ColoredBox(color: AppColors.superset),
            ),
        ],
      ),
    );
  }

  /// Tło bloku superserii — ciepły odcień karty.
  static final _groupColor = Color.alphaBlend(
    AppColors.superset.withValues(alpha: 0.05),
    AppColors.surface,
  );
}

const _headerStyle = TextStyle(
  color: AppColors.textSecondary,
  fontSize: 10,
  fontWeight: FontWeight.w600,
  letterSpacing: 1.0,
);
