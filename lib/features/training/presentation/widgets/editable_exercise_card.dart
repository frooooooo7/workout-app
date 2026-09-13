import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../library/data/exercise_image_uri.dart';
import '../../domain/models/custom_training_plan.dart';
import 'table_cell_input.dart';

class EditableExerciseCard extends StatefulWidget {
  const EditableExerciseCard({
    super.key,
    required this.index,
    required this.planExercise,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final PlanExercise planExercise;
  final ValueChanged<PlanExercise> onChanged;
  final VoidCallback onRemove;

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
    final hasRir = planExercise.sets.any((s) => s.rir != null);
    final hasTempo = planExercise.sets.any((s) => s.tempo != null);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        controller: _controller,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        initiallyExpanded: planExercise.isExpanded,
        shape: const Border(),
        collapsedShape: const Border(),
        onExpansionChanged: (expanded) {
          _commit(planExercise.copyWith(isExpanded: expanded));
        },
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                image: _thumb,
              ),
              child: planExercise.exercise.imageUrl == null
                  ? const Icon(
                      Icons.fitness_center,
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
                    '${planExercise.sets.length} serii',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
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
                const SizedBox(
                  width: 40,
                  child: Text(
                    'SERIA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'CIĘŻAR',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'POWT.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: TableCellInput(
                      hint: '-',
                      value: set.weight ?? '',
                      suffixText: ' kg',
                      onChanged: (val) {
                        final newSets = List<ExerciseSet>.from(planExercise.sets);
                        newSets[setIndex] = set.copyWith(
                          weight: val.isEmpty ? null : val,
                          clearWeight: val.isEmpty,
                        );
                        _commit(
                          planExercise.copyWith(sets: newSets),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TableCellInput(
                      hint: '-',
                      value: set.reps,
                      onChanged: (val) {
                        final newSets = List<ExerciseSet>.from(planExercise.sets);
                        newSets[setIndex] = set.copyWith(reps: val);
                        _commit(
                          planExercise.copyWith(sets: newSets),
                        );
                      },
                    ),
                  ),
                  if (hasRir) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: TableCellInput(
                        hint: '-',
                        value: set.rir ?? '',
                        onChanged: (val) {
                          final newSets =
                              List<ExerciseSet>.from(planExercise.sets);
                          newSets[setIndex] = set.copyWith(rir: val);
                          _commit(
                            planExercise.copyWith(sets: newSets),
                          );
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
                          final newSets =
                              List<ExerciseSet>.from(planExercise.sets);
                          newSets[setIndex] = set.copyWith(tempo: val);
                          _commit(
                            planExercise.copyWith(sets: newSets),
                          );
                        },
                      ),
                    ),
                  ],
                  SizedBox(
                    width: 32,
                    child: IconButton(
                      onPressed: () {
                        final newSets =
                            List<ExerciseSet>.from(planExercise.sets);
                        newSets.removeAt(setIndex);
                        _commit(
                          planExercise.copyWith(sets: newSets),
                        );
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
                    ),
                  );
                  _commit(
                    planExercise.copyWith(sets: newSets),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Dodaj serię'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
              const Spacer(),
              if (!hasRir)
                TextButton(
                  onPressed: () {
                    final newSets = planExercise.sets
                        .map((s) => s.copyWith(rir: ''))
                        .toList();
                    _commit(
                      planExercise.copyWith(sets: newSets),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('+ RIR', style: TextStyle(fontSize: 12)),
                ),
              if (!hasTempo)
                TextButton(
                  onPressed: () {
                    final newSets = planExercise.sets
                        .map((s) => s.copyWith(tempo: ''))
                        .toList();
                    _commit(
                      planExercise.copyWith(sets: newSets),
                    );
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
      ),
    );
  }
}
