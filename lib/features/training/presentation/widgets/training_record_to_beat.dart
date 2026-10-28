import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/units/weight_unit.dart';
import '../../domain/models/custom_training_plan.dart';
import '../../domain/models/training_stats.dart';
import '../../domain/models/training_home_insights.dart';
import '../../domain/models/progression_settings.dart';
import '../../domain/services/progression_engine.dart'
    show isLegExercise, nextWeightKg;

/// Rekord, który można dziś poprawić: [target] to najbliższy krok ponad
/// [record] — ciężar o krok z metody progresji przy tych samych
/// powtórzeniach, a przy wyłączonej progresji (i bez ciężaru) jedno
/// powtórzenie więcej.
typedef RecordToBeat = ({String exercise, String target, String record});

/// Pierwsze ćwiczenie planu z rekordem ciężarowym (zwykle bój główny),
/// a gdy plan ma tylko ćwiczenia z masą własną — pierwsze z rekordem
/// powtórzeń. `null`, gdy żadnego z ćwiczeń jeszcze nie robiono.
RecordToBeat? recordToBeatFor(
  List<PlanExercise> exercises,
  Map<String, ExerciseBest> bests, {
  ProgressionSettings settings = ProgressionSettings.off,
}) {
  ExerciseBest? best(PlanExercise e) =>
      bests[homeExerciseKey(e.exercise.name, e.exercise.id)];

  for (final exercise in exercises) {
    final b = best(exercise);
    final weight = b?.bestWeightKg;
    if (b == null || weight == null || weight <= 0) continue;
    final reps = b.bestWeightReps;
    final String target;
    if (settings.isOff) {
      final heavy = formatWeightWithUnit(weight);
      target = reps == null ? heavy : '$heavy × ${reps + 1}';
    } else {
      final next = formatWeightWithUnit(
        nextWeightKg(
          weight,
          settings,
          legs: isLegExercise(exercise.exercise.muscles.map((m) => m.name)),
        ),
      );
      target = reps == null ? next : '$next × $reps';
    }
    return (
      exercise: exercise.exercise.name,
      target: target,
      record: formatWeightNumber(weight),
    );
  }
  for (final exercise in exercises) {
    final reps = best(exercise)?.maxReps;
    if (reps == null || reps <= 0) continue;
    return (
      exercise: exercise.exercise.name,
      target: '${reps + 1} powt.',
      record: '$reps powt.',
    );
  }
  return null;
}

/// Złoty pasek „Do pobicia” w karcie planu.
class TrainingRecordToBeat extends StatelessWidget {
  const TrainingRecordToBeat({super.key, required this.record});

  final RecordToBeat record;

  static const _textColor = Color(0xFFE9DFC6);
  static const _secondaryStyle = TextStyle(
    color: Color(0xFF9C8F70),
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Do pobicia: ${record.exercise} ${record.target}, '
          'rekord ${record.record}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.record.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.record.withValues(alpha: 0.26)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              size: 18,
              color: AppColors.record,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Do pobicia: ',
                                style: TextStyle(
                                  color: AppColors.record,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(text: record.target),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('rekord ${record.record}', style: _secondaryStyle),
                    ],
                  ),
                  // Nazwa ćwiczenia w osobnej linii — długie nazwy nie
                  // zasłaniają celu.
                  Text(
                    record.exercise,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _secondaryStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
