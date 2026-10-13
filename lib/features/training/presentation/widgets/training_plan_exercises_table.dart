import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/units/weight_unit.dart';
import '../../../../core/utils/polish_plural.dart';
import '../../domain/models/custom_training_plan.dart';
import '../../domain/models/training_home_insights.dart';

/// Tabela „Ćwiczenie · Ostatnio” w karcie dzisiejszego planu: pierwsze
/// [collapsedCount] ćwiczeń i link rozwijający resztę w miejscu.
class TrainingPlanExercisesTable extends StatefulWidget {
  const TrainingPlanExercisesTable({
    super.key,
    required this.exercises,
    this.lastResults = const {},
  });

  final List<PlanExercise> exercises;

  /// Klucz ćwiczenia ([homeExerciseKey]) → ostatni wynik.
  final Map<String, ExerciseLastResult> lastResults;

  static const collapsedCount = 3;

  @override
  State<TrainingPlanExercisesTable> createState() =>
      _TrainingPlanExercisesTableState();
}

class _TrainingPlanExercisesTableState
    extends State<TrainingPlanExercisesTable> {
  bool _expanded = false;

  static const _background = Color(0xFF0D121B);
  static const _divider = Color(0xFF192030);
  static const _headerColor = Color(0xFF6B7487);

  @override
  Widget build(BuildContext context) {
    final all = widget.exercises;
    final hidden = all.length - TrainingPlanExercisesTable.collapsedCount;
    final visible = _expanded || hidden <= 0
        ? all
        : all.take(TrainingPlanExercisesTable.collapsedCount).toList();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedSize(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 7, 0, 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ĆWICZENIE', style: _headerStyle),
                  Text('OSTATNIO', style: _headerStyle),
                ],
              ),
            ),
            for (var i = 0; i < visible.length; i++)
              _ExerciseRow(
                index: i + 1,
                name: visible[i].exercise.name,
                result: _formatResult(
                  widget.lastResults[homeExerciseKey(
                    visible[i].exercise.name,
                    visible[i].exercise.id,
                  )],
                ),
                showDivider: i < visible.length - 1,
                dividerColor: _divider,
              ),
            if (hidden > 0)
              _ExpandLink(
                label: _expanded
                    ? 'Zwiń listę'
                    : '+ $hidden ${polishPlural(hidden, 'kolejne ćwiczenie', 'kolejne ćwiczenia', 'kolejnych ćwiczeń')}',
                onTap: () => setState(() => _expanded = !_expanded),
              ),
          ],
        ),
      ),
    );
  }

  static const _headerStyle = TextStyle(
    color: _headerColor,
    fontSize: 10.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.84,
  );
}

/// `92,5 × 6`, `12 powt.` (masa własna); `—`, gdy ćwiczenia jeszcze nie
/// robiono.
String _formatResult(ExerciseLastResult? result) {
  if (result == null) return '—';
  final weight = result.weightKg;
  final reps = result.reps;
  if (weight == null) return reps == null ? '—' : '$reps powt.';
  final value = formatWeightNumber(weight);
  return reps == null ? value : '$value × $reps';
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.index,
    required this.name,
    required this.result,
    required this.showDivider,
    required this.dividerColor,
  });

  final int index;
  final String name;
  final String result;
  final bool showDivider;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: showDivider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: dividerColor)),
            )
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 16,
            child: Text(
              '$index',
              style: _TrainingPlanExercisesTableState._headerStyle.copyWith(
                fontSize: 12,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            result,
            style: AppTextStyles.number(
              size: 17,
              weight: FontWeight.w600,
              color: AppColors.iconOnTile,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandLink extends StatelessWidget {
  const _ExpandLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 6, 0, 4),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.primaryVariant,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
