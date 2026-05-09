import 'package:uuid/uuid.dart';

import '../../../library/domain/models/exercise.dart';

class ExerciseSet {
  ExerciseSet({
    String? id,
    this.weight,
    this.reps = '',
    this.rir,
    this.tempo,
  }) : id = id ?? const Uuid().v4();

  final String id;
  final String? weight;
  final String reps;
  final String? rir;
  final String? tempo;

  ExerciseSet copyWith({
    String? id,
    String? weight,
    String? reps,
    String? rir,
    String? tempo,
    bool clearWeight = false,
    bool clearRir = false,
    bool clearTempo = false,
  }) {
    return ExerciseSet(
      id: id ?? this.id,
      weight: clearWeight ? null : (weight ?? this.weight),
      reps: reps ?? this.reps,
      rir: clearRir ? null : (rir ?? this.rir),
      tempo: clearTempo ? null : (tempo ?? this.tempo),
    );
  }
}

class PlanExercise {
  PlanExercise({
    String? id,
    required this.exercise,
    List<ExerciseSet>? sets,
    this.isExpanded = false,
  })  : id = id ?? const Uuid().v4(),
        sets = sets ?? [ExerciseSet()]; // Domyślnie jedna pusta seria

  final String id;
  final Exercise exercise;
  final List<ExerciseSet> sets;
  final bool isExpanded;

  PlanExercise copyWith({
    String? id,
    Exercise? exercise,
    List<ExerciseSet>? sets,
    bool? isExpanded,
  }) {
    return PlanExercise(
      id: id ?? this.id,
      exercise: exercise ?? this.exercise,
      sets: sets ?? this.sets,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}

class CustomTrainingPlan {
  CustomTrainingPlan({
    String? id,
    required this.name,
    this.note,
    this.exercises = const [],
    this.selectedDays = const [],
  }) : id = id ?? const Uuid().v4();

  final String id;
  final String name;
  final String? note;
  final List<PlanExercise> exercises;
  final List<int> selectedDays; // 1 = Poniedziałek, ..., 7 = Niedziela

  CustomTrainingPlan copyWith({
    String? id,
    String? name,
    String? note,
    List<PlanExercise>? exercises,
    List<int>? selectedDays,
    bool clearNote = false,
  }) {
    return CustomTrainingPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      note: clearNote ? null : (note ?? this.note),
      exercises: exercises ?? this.exercises,
      selectedDays: selectedDays ?? this.selectedDays,
    );
  }
}
