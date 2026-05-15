import 'package:uuid/uuid.dart';

import 'custom_training_plan.dart';

enum TrainingSessionStatus { active, completed, cancelled }

class TrainingSessionSet {
  TrainingSessionSet({
    String? id,
    this.plannedWeight,
    this.plannedReps = '',
    this.plannedRir,
    this.plannedTempo,
    this.actualWeight,
    this.actualReps,
    this.actualRir,
    this.actualTempo,
    this.completed = false,
    this.completedAt,
  }) : id = id ?? const Uuid().v4();

  final String id;
  final String? plannedWeight;
  final String plannedReps;
  final String? plannedRir;
  final String? plannedTempo;
  final String? actualWeight;
  final String? actualReps;
  final String? actualRir;
  final String? actualTempo;
  final bool completed;
  final DateTime? completedAt;

  TrainingSessionSet copyWith({
    String? id,
    String? plannedWeight,
    String? plannedReps,
    String? plannedRir,
    String? plannedTempo,
    String? actualWeight,
    String? actualReps,
    String? actualRir,
    String? actualTempo,
    bool? completed,
    DateTime? completedAt,
    bool clearActualWeight = false,
    bool clearActualReps = false,
    bool clearActualRir = false,
    bool clearActualTempo = false,
    bool clearCompletedAt = false,
  }) {
    return TrainingSessionSet(
      id: id ?? this.id,
      plannedWeight: plannedWeight ?? this.plannedWeight,
      plannedReps: plannedReps ?? this.plannedReps,
      plannedRir: plannedRir ?? this.plannedRir,
      plannedTempo: plannedTempo ?? this.plannedTempo,
      actualWeight: clearActualWeight
          ? null
          : (actualWeight ?? this.actualWeight),
      actualReps: clearActualReps ? null : (actualReps ?? this.actualReps),
      actualRir: clearActualRir ? null : (actualRir ?? this.actualRir),
      actualTempo: clearActualTempo ? null : (actualTempo ?? this.actualTempo),
      completed: completed ?? this.completed,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }
}

class TrainingSessionExercise {
  TrainingSessionExercise({
    String? id,
    required this.exerciseId,
    required this.exerciseName,
    required this.exerciseMuscles,
    required this.exerciseCategory,
    this.exerciseImageUrl,
    required this.sets,
  }) : id = id ?? const Uuid().v4();

  final String id;
  final String exerciseId;
  final String exerciseName;
  final List<String> exerciseMuscles;
  final String exerciseCategory;
  final String? exerciseImageUrl;
  final List<TrainingSessionSet> sets;

  TrainingSessionExercise copyWith({
    String? id,
    String? exerciseId,
    String? exerciseName,
    List<String>? exerciseMuscles,
    String? exerciseCategory,
    String? exerciseImageUrl,
    List<TrainingSessionSet>? sets,
  }) {
    return TrainingSessionExercise(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      exerciseMuscles: exerciseMuscles ?? this.exerciseMuscles,
      exerciseCategory: exerciseCategory ?? this.exerciseCategory,
      exerciseImageUrl: exerciseImageUrl ?? this.exerciseImageUrl,
      sets: sets ?? this.sets,
    );
  }
}

class TrainingSession {
  TrainingSession({
    String? id,
    this.serverId,
    this.planLocalId,
    this.planServerId,
    required this.planName,
    this.status = TrainingSessionStatus.active,
    this.note,
    DateTime? startedAt,
    this.finishedAt,
    required this.exercises,
    this.pendingOp,
  }) : id = id ?? const Uuid().v4(),
       startedAt = startedAt ?? DateTime.now().toUtc();

  final String id;
  final String? serverId;
  final String? planLocalId;
  final String? planServerId;
  final String planName;
  final TrainingSessionStatus status;
  final String? note;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<TrainingSessionExercise> exercises;
  final String? pendingOp;

  bool get isActive => status == TrainingSessionStatus.active;

  TrainingSession copyWith({
    String? id,
    String? serverId,
    String? planLocalId,
    String? planServerId,
    String? planName,
    TrainingSessionStatus? status,
    String? note,
    DateTime? startedAt,
    DateTime? finishedAt,
    List<TrainingSessionExercise>? exercises,
    String? pendingOp,
    bool clearFinishedAt = false,
  }) {
    return TrainingSession(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      planLocalId: planLocalId ?? this.planLocalId,
      planServerId: planServerId ?? this.planServerId,
      planName: planName ?? this.planName,
      status: status ?? this.status,
      note: note ?? this.note,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: clearFinishedAt ? null : (finishedAt ?? this.finishedAt),
      exercises: exercises ?? this.exercises,
      pendingOp: pendingOp ?? this.pendingOp,
    );
  }

  factory TrainingSession.fromPlan(
    CustomTrainingPlan plan, {
    String? planServerId,
  }) {
    return TrainingSession(
      planLocalId: plan.id,
      planServerId: planServerId,
      planName: plan.name,
      exercises: plan.exercises
          .map(
            (exercise) => TrainingSessionExercise(
              exerciseId: exercise.exercise.id,
              exerciseName: exercise.exercise.name,
              exerciseMuscles: exercise.exercise.muscles
                  .map((m) => m.name)
                  .toList(),
              exerciseCategory: exercise.exercise.category.name,
              exerciseImageUrl: exercise.exercise.imageUrl,
              sets: exercise.sets
                  .map(
                    (set) => TrainingSessionSet(
                      plannedWeight: set.weight,
                      plannedReps: set.reps,
                      plannedRir: set.rir,
                      plannedTempo: set.tempo,
                      actualWeight: set.weight,
                      actualReps: set.reps,
                      actualRir: set.rir,
                      actualTempo: set.tempo,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }
}
