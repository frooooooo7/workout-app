import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/models/training_session.dart';
import '../../../domain/services/superset_rounds.dart';
import 'superset_block_card.dart';

/// Wynik arkusza „Lista ćwiczeń”: nowa kolejność i/lub ćwiczenie, do którego
/// przejść.
class ExerciseListResult {
  const ExerciseListResult({this.order, this.goToExerciseId});

  /// Nowa kolejność bloków (indeksy z [SupersetRounds.blocks]); `null`, gdy
  /// nic się nie zmieniło.
  final List<int>? order;

  /// Ćwiczenie wybrane dotknięciem wiersza (w superserii to, które jest
  /// teraz na kolei); `null` po „Gotowe”.
  final String? goToExerciseId;
}

/// Arkusz „Lista ćwiczeń” w trakcie treningu: dotknięcie wiersza przenosi do
/// ćwiczenia, przeciąganie za uchwyt (albo przytrzymanie wiersza) zmienia
/// kolejność. Superseria przesuwa się w całości.
Future<ExerciseListResult?> showExerciseOrderSheet(
  BuildContext context, {
  required List<TrainingSessionExercise> exercises,
  int? highlightBlock,
}) async {
  // Zamknięcie gestem albo dotknięciem tła nie zwraca wyniku, ale przestawiona
  // kolejność nie ma przepaść — arkusz zgłasza ją osobno.
  List<int>? dismissedOrder;
  final result = await showModalBottomSheet<ExerciseListResult>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ExerciseOrderSheet(
      exercises: exercises,
      highlightBlock: highlightBlock,
      onDismissedWithOrder: (order) => dismissedOrder = order,
    ),
  );
  if (result != null) return result;
  final order = dismissedOrder;
  return order == null ? null : ExerciseListResult(order: order);
}

class _ExerciseOrderSheet extends StatefulWidget {
  const _ExerciseOrderSheet({
    required this.exercises,
    required this.onDismissedWithOrder,
    this.highlightBlock,
  });

  final List<TrainingSessionExercise> exercises;
  final int? highlightBlock;
  final ValueChanged<List<int>> onDismissedWithOrder;

  @override
  State<_ExerciseOrderSheet> createState() => _ExerciseOrderSheetState();
}

class _ExerciseOrderSheetState extends State<_ExerciseOrderSheet> {
  late final List<List<int>> _blocks = SupersetRounds.blocks(widget.exercises);
  late final List<int> _order = [for (var i = 0; i < _blocks.length; i++) i];

  List<int>? get _result => _changed ? List<int>.of(_order) : null;

  bool get _changed {
    for (var i = 0; i < _order.length; i++) {
      if (_order[i] != i) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        final order = _result;
        if (didPop && result == null && order != null) {
          widget.onDismissedWithOrder(order);
        }
      },
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(
                  'Lista ćwiczeń',
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
                  'Dotknij, żeby przejść do ćwiczenia. Przeciągnij za uchwyt, '
                  'żeby zmienić kolejność — zrobione serie zostają przy swoim '
                  'ćwiczeniu.',
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
                          onTap: () => Navigator.of(context).pop(
                            ExerciseListResult(
                              order: _result,
                              goToExerciseId: widget
                                  .exercises[SupersetRounds.focusOf(
                                    widget.exercises,
                                    _blocks[blockIndex],
                                  )]
                                  .id,
                            ),
                          ),
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
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(_changed ? ExerciseListResult(order: _result) : null),
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
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.position,
    required this.exercises,
    required this.highlighted,
    required this.onTap,
  });

  final int position;
  final VoidCallback onTap;

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
      child: Material(
        color: highlighted
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: highlighted
                ? AppColors.primary.withValues(alpha: 0.45)
                : AppColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
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
        ),
      ),
    );
  }
}
