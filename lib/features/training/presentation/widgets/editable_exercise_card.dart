import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
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
  
  @override
  void didUpdateWidget(covariant EditableExerciseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.planExercise.isExpanded != widget.planExercise.isExpanded) {
      if (widget.planExercise.isExpanded) {
        if (!_controller.isExpanded) _controller.expand();
      } else {
        if (_controller.isExpanded) _controller.collapse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final planExercise = widget.planExercise;
    final hasRir = planExercise.sets.any((s) => s.rir != null);
    final hasTempo = planExercise.sets.any((s) => s.tempo != null);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          controller: _controller,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          initiallyExpanded: planExercise.isExpanded,
          onExpansionChanged: (expanded) {
            widget.onChanged(planExercise.copyWith(isExpanded: expanded));
          },
          title: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  image: planExercise.exercise.imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(planExercise.exercise.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: planExercise.exercise.imageUrl == null
                    ? const Icon(Icons.fitness_center, color: AppColors.textMuted, size: 24)
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
                  const SizedBox(width: 40, child: Text('SERIA', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.0))),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('CIĘŻAR', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.0))),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('POWT.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.0))),
                  if (hasRir) ...const [
                    SizedBox(width: 8),
                    Expanded(child: Text('RIR', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.0))),
                  ],
                  if (hasTempo) ...const [
                    SizedBox(width: 8),
                    Expanded(child: Text('TEMPO', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.0))),
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
                          newSets[setIndex] = set.copyWith(weight: val.isEmpty ? null : val, clearWeight: val.isEmpty);
                          widget.onChanged(planExercise.copyWith(sets: newSets));
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
                          widget.onChanged(planExercise.copyWith(sets: newSets));
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
                            final newSets = List<ExerciseSet>.from(planExercise.sets);
                            newSets[setIndex] = set.copyWith(rir: val);
                            widget.onChanged(planExercise.copyWith(sets: newSets));
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
                            final newSets = List<ExerciseSet>.from(planExercise.sets);
                            newSets[setIndex] = set.copyWith(tempo: val);
                            widget.onChanged(planExercise.copyWith(sets: newSets));
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
                          widget.onChanged(planExercise.copyWith(sets: newSets));
                        },
                        icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
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
                    widget.onChanged(planExercise.copyWith(sets: newSets));
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Dodaj serię'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                const Spacer(),
                if (!hasRir)
                  TextButton(
                    onPressed: () {
                      final newSets = planExercise.sets.map((s) => s.copyWith(rir: '')).toList();
                      widget.onChanged(planExercise.copyWith(sets: newSets));
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
                      final newSets = planExercise.sets.map((s) => s.copyWith(tempo: '')).toList();
                      widget.onChanged(planExercise.copyWith(sets: newSets));
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
      ),
    );
  }
}
