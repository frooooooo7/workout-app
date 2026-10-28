import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/models/training_session.dart';
import '../../../domain/services/superset_rounds.dart';
import 'superset_block_card.dart';

/// Arkusz „Kolejność ćwiczeń” w trakcie treningu: przeciąganie za uchwyt
/// (albo przytrzymanie wiersza). Superseria przesuwa się w całości.
///
/// Zwraca nową kolejność bloków (indeksy z [SupersetRounds.blocks]) albo
/// `null`, gdy nic się nie zmieniło.
Future<List<int>?> showExerciseOrderSheet(
  BuildContext context, {
  required List<TrainingSessionExercise> exercises,
  int? highlightBlock,
}) {
  return showModalBottomSheet<List<int>>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ExerciseOrderSheet(
      exercises: exercises,
      highlightBlock: highlightBlock,
    ),
  );
}

class _ExerciseOrderSheet extends StatefulWidget {
  const _ExerciseOrderSheet({required this.exercises, this.highlightBlock});

  final List<TrainingSessionExercise> exercises;
  final int? highlightBlock;

  @override
  State<_ExerciseOrderSheet> createState() => _ExerciseOrderSheetState();
}

class _ExerciseOrderSheetState extends State<_ExerciseOrderSheet> {
  late final List<List<int>> _blocks = SupersetRounds.blocks(widget.exercises);
  late final List<int> _order = [for (var i = 0; i < _blocks.length; i++) i];

  bool get _changed {
    for (var i = 0; i < _order.length; i++) {
      if (_order[i] != i) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                'Kolejność ćwiczeń',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'Przeciągnij za uchwyt, żeby przestawić. Zrobione serie '
                'zostają przy swoim ćwiczeniu.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
            Flexible(
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(canvasColor: Colors.transparent),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  itemCount: _order.length,
                  proxyDecorator: (child, _, _) => Material(
                    color: Colors.transparent,
                    elevation: 8,
                    shadowColor: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                    child: child,
                  ),
                  onReorderItem: (oldIndex, newIndex) => setState(() {
                    final item = _order.removeAt(oldIndex);
                    _order.insert(newIndex, item);
                  }),
                  itemBuilder: (context, position) {
                    final blockIndex = _order[position];
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey('order-block-$blockIndex'),
                      index: position,
                      child: _OrderRow(
                        position: position,
                        exercises: [
                          for (final i in _blocks[blockIndex])
                            widget.exercises[i],
                        ],
                        highlighted: blockIndex == widget.highlightBlock,
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: FilledButton(
                key: const ValueKey('exercise-order-save'),
                onPressed: () =>
                    Navigator.of(context).pop(_changed ? _order : null),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('Gotowe'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.position,
    required this.exercises,
    required this.highlighted,
  });

  final int position;

  /// Jedno ćwiczenie albo cała superseria.
  final List<TrainingSessionExercise> exercises;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final group = exercises.length > 1 ? exercises.first.supersetGroup : null;
    final sets = exercises
        .expand((e) => e.sets)
        .where((s) => s.countsTowardStats);
    final done = sets.where((s) => s.completed).length;
    final finished = sets.isNotEmpty && done == sets.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(
          color: highlighted
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlighted
                ? AppColors.primary.withValues(alpha: 0.45)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: finished
                    ? AppColors.success.withValues(alpha: 0.18)
                    : AppColors.background,
                shape: BoxShape.circle,
              ),
              child: finished
                  ? const Icon(
                      Icons.check_rounded,
                      size: 17,
                      color: AppColors.success,
                    )
                  : Text(
                      '${position + 1}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (group != null) ...[
                    SupersetChip(group: group),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    exercises.map((e) => e.exerciseName).join(' + '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$done / ${sets.length} serii',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            ReorderableDragStartListener(
              index: position,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
