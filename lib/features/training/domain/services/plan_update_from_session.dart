import '../../../../core/units/weight_unit.dart';
import '../models/custom_training_plan.dart';
import '../models/training_session.dart';
import 'training_session_detail_mapper.dart' show parseReps, parseWeightKg;

/// Jedno ćwiczenie planu po treningu: serie przed i po, np.
/// `60 × 8, 60 × 8` → `65 × 8, 62,5 × 8`.
class PlanExerciseUpdate {
  const PlanExerciseUpdate({
    required this.exerciseName,
    required this.before,
    required this.after,
  });

  final String exerciseName;
  final String before;
  final String after;
}

/// Propozycja „Zaktualizuj plan”: plan z ciężarami i powtórzeniami z
/// treningu oraz lista zmian do pokazania użytkownikowi.
class PlanUpdateProposal {
  const PlanUpdateProposal({required this.plan, required this.changes});

  /// Plan po zmianach — gotowy do zapisu.
  final CustomTrainingPlan plan;
  final List<PlanExerciseUpdate> changes;
}

/// Porównuje [plan] z ukończonym treningiem [session] (zrobionym z tego
/// planu) i proponuje nowe wartości serii. `null`, gdy nic się nie zmienia.
///
/// Zasady:
/// * ćwiczenia dopasowujemy po identyfikatorze, w kolejności planu
///   (to samo ćwiczenie dwa razy w planie = dwa kolejne w treningu),
/// * serię planu nr N zmienia tylko odhaczona seria N z treningu,
/// * ciężar bierzemy, gdy był wpisany; powtórzenia — gdy plan ma pojedynczą
///   liczbę (zakres „8–12” zostaje, bo to cel, nie wynik),
/// * serii nie dodajemy ani nie usuwamy, kardio i RIR / tempo zostają bez
///   zmian.
PlanUpdateProposal? planUpdateFromSession(
  CustomTrainingPlan plan,
  TrainingSession session,
) {
  final used = <int>{};
  final changes = <PlanExerciseUpdate>[];
  final exercises = <PlanExercise>[];
  for (final planExercise in plan.exercises) {
    final match = _matchExercise(session.exercises, planExercise, used);
    if (match == null || planExercise.exercise.tracking.tracksDuration) {
      exercises.add(planExercise);
      continue;
    }
    used.add(match);
    final done = session.exercises[match];
    final sets = <ExerciseSet>[];
    var changed = false;
    for (var i = 0; i < planExercise.sets.length; i++) {
      final planSet = planExercise.sets[i];
      final sessionSet = i < done.sets.length ? done.sets[i] : null;
      final updated = sessionSet == null || !sessionSet.completed
          ? planSet
          : _updatedSet(planSet, sessionSet);
      if (!identical(updated, planSet)) changed = true;
      sets.add(updated);
    }
    if (!changed) {
      exercises.add(planExercise);
      continue;
    }
    exercises.add(planExercise.copyWith(sets: sets));
    changes.add(
      PlanExerciseUpdate(
        exerciseName: planExercise.exercise.name,
        before: _describe(planExercise.sets),
        after: _describe(sets),
      ),
    );
  }
  if (changes.isEmpty) return null;
  return PlanUpdateProposal(
    plan: plan.copyWith(exercises: exercises),
    changes: changes,
  );
}

int? _matchExercise(
  List<TrainingSessionExercise> done,
  PlanExercise planExercise,
  Set<int> used,
) {
  final id = planExercise.exercise.id;
  final name = planExercise.exercise.name.trim().toLowerCase();
  for (var i = 0; i < done.length; i++) {
    if (used.contains(i)) continue;
    final exercise = done[i];
    if (exercise.exerciseId == id ||
        exercise.exerciseName.trim().toLowerCase() == name) {
      return i;
    }
  }
  return null;
}

/// Ta sama instancja, gdy nic się nie zmienia.
ExerciseSet _updatedSet(ExerciseSet planSet, TrainingSessionSet done) {
  final doneWeight = parseWeightKg(done.actualWeight);
  final planWeight = parseWeightKg(planSet.weight);
  final newWeight =
      doneWeight != null &&
          (planWeight == null || (doneWeight - planWeight).abs() >= 0.01)
      ? done.actualWeight!.trim()
      : null;

  final doneReps = parseReps(done.actualReps);
  final planIsSingleNumber =
      planSet.reps.trim().isEmpty || parseReps(planSet.reps) != null;
  final newReps =
      doneReps != null &&
          doneReps > 0 &&
          planIsSingleNumber &&
          doneReps != parseReps(planSet.reps)
      ? '$doneReps'
      : null;

  if (newWeight == null && newReps == null) return planSet;
  return planSet.copyWith(weight: newWeight, reps: newReps);
}

/// `60 × 8, 60 × 8, 55 × 10` (ciężar w aktualnej jednostce).
String _describe(List<ExerciseSet> sets) {
  final parts = <String>[];
  for (final set in sets) {
    final kg = parseWeightKg(set.weight);
    final reps = set.reps.trim();
    final weight = kg == null ? '' : formatWeightNumber(kg);
    parts.add(switch ((weight.isEmpty, reps.isEmpty)) {
      (true, true) => '—',
      (true, false) => '× $reps',
      (false, true) => weight,
      (false, false) => '$weight × $reps',
    });
  }
  return parts.join(', ');
}
