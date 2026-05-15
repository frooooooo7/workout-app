enum TrainingSessionStatus { completed, cancelled, active }

enum TrainingProgressHighlightType {
  weightIncrease,
  volumeIncrease,
  noProgress,
}

class TrainingPlanSummary {
  const TrainingPlanSummary({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class TrainingProgressHighlight {
  const TrainingProgressHighlight({
    required this.type,
    required this.label,
  });

  final TrainingProgressHighlightType type;
  final String label;
}

class TrainingSessionListItem {
  const TrainingSessionListItem({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.durationSec,
    required this.status,
    required this.plan,
    required this.exercisesCount,
    required this.completedSetsCount,
    required this.hasNote,
    this.progressHighlight,
    required this.updatedAt,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSec;
  final TrainingSessionStatus status;
  final TrainingPlanSummary plan;
  final int exercisesCount;
  final int completedSetsCount;
  final bool hasNote;
  final TrainingProgressHighlight? progressHighlight;
  final DateTime updatedAt;
}

class TrainingSetMetrics {
  const TrainingSetMetrics({
    this.weightKg,
    this.reps,
    this.rir,
    this.tempo,
  });

  final double? weightKg;
  final int? reps;
  final int? rir;
  final String? tempo;
}

class TrainingExerciseSetDetail {
  const TrainingExerciseSetDetail({
    required this.setIndex,
    this.planned,
    this.actual,
    required this.completed,
  });

  final int setIndex;
  final TrainingSetMetrics? planned;
  final TrainingSetMetrics? actual;
  final bool completed;
}

class TrainingExerciseDetail {
  const TrainingExerciseDetail({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
  });

  final String exerciseId;
  final String exerciseName;
  final List<TrainingExerciseSetDetail> sets;
}

class TrainingSessionDetail {
  const TrainingSessionDetail({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.durationSec,
    required this.status,
    required this.plan,
    required this.note,
    required this.exercises,
    required this.updatedAt,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSec;
  final TrainingSessionStatus status;
  final TrainingPlanSummary plan;
  final String? note;
  final List<TrainingExerciseDetail> exercises;
  final DateTime updatedAt;
}

class TrainingSessionPage {
  const TrainingSessionPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    required this.isFromCache,
  });

  final List<TrainingSessionListItem> items;
  final String? nextCursor;
  final bool hasMore;
  final bool isFromCache;
}

