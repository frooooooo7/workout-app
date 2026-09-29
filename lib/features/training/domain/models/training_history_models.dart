import '../../../library/domain/models/exercise.dart';
import 'training_session.dart';

export 'set_type.dart';
export 'training_session.dart' show TrainingSessionStatus;

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
    this.totalVolumeKg,
    this.prsCount,
    this.targetMuscles,
    this.avgRpe,
    this.avgRestSec,
    this.topSetHighlight,
    this.notePreview,
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
  final double? totalVolumeKg;
  final int? prsCount;
  final List<String>? targetMuscles;
  final double? avgRpe;
  final int? avgRestSec;
  final String? topSetHighlight;
  final String? notePreview;
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
    this.setType = SetType.normal,
    this.planned,
    this.actual,
    required this.completed,
    this.completedAt,
  });

  final int setIndex;
  final SetType setType;
  final TrainingSetMetrics? planned;
  final TrainingSetMetrics? actual;
  final bool completed;

  /// Moment odhaczenia serii (UTC). `null` dla serii nieukończonych oraz dla
  /// sesji sprzed wprowadzenia tego pola — oś czasu musi to znieść.
  final DateTime? completedAt;

  /// Czy seria wlicza się do objętości, liczby serii i „top setu”
  /// (rozgrzewki nie).
  bool get countsTowardStats => setType.countsTowardStats;

  /// Objętość serii w kg (ciężar × powtórzenia). Liczona z wykonania, nie
  /// z planu; seria nieukończona, rozgrzewkowa lub bez kompletu liczb daje `0`.
  double get volumeKg {
    if (!completed || !countsTowardStats) return 0;
    final weight = actual?.weightKg;
    final reps = actual?.reps;
    if (weight == null || reps == null) return 0;
    return weight * reps;
  }
}

class TrainingExerciseDetail {
  const TrainingExerciseDetail({
    required this.exerciseId,
    required this.exerciseName,
    this.muscles = const [],
    this.imageUrl,
    this.note,
    required this.sets,
  });

  final String exerciseId;
  final String exerciseName;

  /// Snapshot grup mięśniowych z chwili wykonania sesji — nie zmienia się,
  /// gdy ćwiczenie zostanie później przetagowane albo usunięte z biblioteki.
  final List<MuscleGroup> muscles;

  /// Ścieżka względna uploadu lub absolutny URL; do rozwinięcia przez
  /// `exerciseImageResolvedUri`.
  final String? imageUrl;

  /// Notatka do ćwiczenia w tej sesji.
  final String? note;

  final List<TrainingExerciseSetDetail> sets;

  /// Serie, które wchodzą do statystyk (bez rozgrzewek) — mianownik „x/y serii”.
  int get workingSetsCount => sets.where((s) => s.countsTowardStats).length;

  int get completedSetsCount =>
      sets.where((s) => s.completed && s.countsTowardStats).length;

  double get volumeKg =>
      sets.fold(0, (sum, set) => sum + set.volumeKg);

  /// Pierwszy i ostatni moment odhaczenia serii — punkt zaczepienia na osi
  /// czasu. `null`, gdy żadna seria nie ma znacznika.
  DateTime? get startedAt {
    final stamps = sets
        .map((s) => s.completedAt)
        .whereType<DateTime>()
        .toList(growable: false);
    if (stamps.isEmpty) return null;
    return stamps.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  DateTime? get finishedAt {
    final stamps = sets
        .map((s) => s.completedAt)
        .whereType<DateTime>()
        .toList(growable: false);
    if (stamps.isEmpty) return null;
    return stamps.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Najcięższa ukończona seria robocza — „top set" pokazywany w stopce karty.
  TrainingExerciseSetDetail? get topSet {
    TrainingExerciseSetDetail? best;
    for (final set in sets) {
      if (!set.completed || !set.countsTowardStats) continue;
      final weight = set.actual?.weightKg;
      if (weight == null) continue;
      if (best == null || weight > (best.actual?.weightKg ?? 0)) best = set;
    }
    return best;
  }
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
    this.sharedToProfile = false,
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
  final bool sharedToProfile;

  int get completedSetsCount =>
      exercises.fold(0, (sum, e) => sum + e.completedSetsCount);

  /// Serie robocze całej sesji (bez rozgrzewek) — mianownik „x/y serii”.
  int get workingSetsCount =>
      exercises.fold(0, (sum, e) => sum + e.workingSetsCount);

  double get totalVolumeKg =>
      exercises.fold(0, (sum, e) => sum + e.volumeKg);

  /// Czy sesja niesie znaczniki czasu serii. Sesje sprzed dodania
  /// `completedAt` ich nie mają — oś czasu wtedy rezygnuje z godzin.
  bool get hasSetTimestamps =>
      exercises.any((e) => e.sets.any((s) => s.completedAt != null));
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

