import '../../../../library/domain/models/exercise_stats.dart';
import '../../models/training_session.dart';
import '../../models/training_stats.dart';
import 'stats_sets.dart';

class PersonalRecordsResult {
  const PersonalRecordsResult({required this.records, required this.bests});

  /// Wszystkie pobite rekordy, od najstarszego.
  final List<PersonalRecord> records;

  /// Najlepsze wyniki ćwiczeń, ostatnio poprawione najpierw.
  final List<ExerciseBest> bests;

  static const empty = PersonalRecordsResult(records: [], bests: []);
}

/// Wykrywa rekordy, przechodząc historię od najstarszej sesji: sesja bije
/// rekord, gdy jej najlepsza seria przebija wszystko, co było wcześniej.
/// Pierwsze wykonanie ćwiczenia ustala punkt odniesienia i nie jest rekordem —
/// inaczej każde nowe ćwiczenie zasypywałoby listę.
abstract final class PersonalRecordsCalculator {
  /// Poniżej tej różnicy (kg) 1RM traktujemy jako remis — Epley daje ułamki,
  /// a 0,01 kg „poprawy” to szum z zaokrągleń.
  static const _oneRepMaxEpsilon = 0.05;

  static PersonalRecordsResult compute(Iterable<TrainingSession> sessions) {
    final ordered = [
      for (final s in sessions)
        if (s.status == TrainingSessionStatus.completed) s,
    ]..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    final bests = <String, _Best>{};
    final records = <PersonalRecord>[];

    for (final session in ordered) {
      final perExercise = <String, _SessionTop>{};
      for (final exercise in session.exercises) {
        final key = statsExerciseKey(exercise);
        for (final set in completedSetsOf(exercise)) {
          (perExercise[key] ??= _SessionTop(exercise)).add(set);
        }
      }

      for (final entry in perExercise.entries) {
        final top = entry.value;
        if (!top.hasAnySet) continue;
        final best = bests[entry.key];
        final date = session.startedAt;

        if (best == null) {
          bests[entry.key] = _Best.from(top, date);
          continue;
        }

        final kinds = <PersonalRecordKind>{};
        double? improvement;
        final weight = top.weightKg;
        if (weight != null && weight > (best.weightKg ?? 0)) {
          kinds.add(PersonalRecordKind.weight);
          improvement = best.weightKg == null ? null : weight - best.weightKg!;
        }
        final oneRm = top.oneRepMaxKg;
        if (oneRm != null &&
            oneRm > (best.oneRepMaxKg ?? 0) + _oneRepMaxEpsilon) {
          kinds.add(PersonalRecordKind.oneRepMax);
          if (improvement == null && best.oneRepMaxKg != null) {
            improvement = oneRm - best.oneRepMaxKg!;
          }
        }
        final reps = top.bodyweightReps;
        if (reps != null && reps > (best.bodyweightReps ?? 0)) {
          kinds.add(PersonalRecordKind.reps);
          if (kinds.length == 1 && best.bodyweightReps != null) {
            improvement = (reps - best.bodyweightReps!).toDouble();
          }
        }

        best.sessions++;
        if (kinds.isEmpty) {
          best.name = top.name;
          best.exerciseId = top.exerciseId;
          continue;
        }

        final primaryIsWeight = kinds.contains(PersonalRecordKind.weight);
        final primaryIsOneRm =
            !primaryIsWeight && kinds.contains(PersonalRecordKind.oneRepMax);
        records.add(
          PersonalRecord(
            exerciseKey: entry.key,
            exerciseName: top.name,
            exerciseId: top.exerciseId,
            sessionId: session.id,
            date: date,
            kinds: kinds,
            weightKg: primaryIsWeight
                ? weight
                : primaryIsOneRm
                ? top.oneRepMaxSetWeightKg
                : null,
            reps: primaryIsWeight
                ? top.weightReps
                : primaryIsOneRm
                ? top.oneRepMaxSetReps
                : reps,
            oneRepMaxKg: oneRm,
            improvement: improvement,
          ),
        );
        best.absorb(top, date);
      }
    }

    final bestList = [
      for (final entry in bests.entries) entry.value.toExerciseBest(entry.key),
    ]..sort((a, b) => b.lastImprovedAt.compareTo(a.lastImprovedAt));

    return PersonalRecordsResult(records: records, bests: bestList);
  }
}

/// Najlepsze wartości ćwiczenia w jednej sesji.
class _SessionTop {
  _SessionTop(TrainingSessionExercise exercise)
    : name = exercise.exerciseName.trim(),
      exerciseId = exercise.exerciseId;

  final String name;
  final String exerciseId;
  bool hasAnySet = false;
  double? weightKg;
  int? weightReps;
  double? oneRepMaxKg;
  double? oneRepMaxSetWeightKg;
  int? oneRepMaxSetReps;
  int? bodyweightReps;

  void add(CompletedSetValues set) {
    hasAnySet = true;
    final reps = set.reps;
    if (set.hasWeight) {
      final w = set.weightKg!;
      if (weightKg == null ||
          w > weightKg! ||
          (w == weightKg && (reps ?? 0) > (weightReps ?? 0))) {
        weightKg = w;
        weightReps = reps;
      }
      if (reps != null) {
        final oneRm = ExerciseStats.estimateOneRepMax(w, reps);
        if (oneRm > (oneRepMaxKg ?? 0)) {
          oneRepMaxKg = oneRm;
          oneRepMaxSetWeightKg = w;
          oneRepMaxSetReps = reps;
        }
      }
    } else if (reps != null && reps > (bodyweightReps ?? 0)) {
      bodyweightReps = reps;
    }
  }
}

class _Best {
  _Best({
    required this.name,
    required this.exerciseId,
    required this.lastImprovedAt,
    this.weightKg,
    this.weightReps,
    this.oneRepMaxKg,
    this.bodyweightReps,
  });

  factory _Best.from(_SessionTop top, DateTime date) => _Best(
    name: top.name,
    exerciseId: top.exerciseId,
    lastImprovedAt: date,
    weightKg: top.weightKg,
    weightReps: top.weightReps,
    oneRepMaxKg: top.oneRepMaxKg,
    bodyweightReps: top.bodyweightReps,
  );

  String name;
  String exerciseId;
  DateTime lastImprovedAt;
  int sessions = 1;
  double? weightKg;
  int? weightReps;
  double? oneRepMaxKg;
  int? bodyweightReps;

  void absorb(_SessionTop top, DateTime date) {
    name = top.name;
    exerciseId = top.exerciseId;
    lastImprovedAt = date;
    if (top.weightKg != null && top.weightKg! > (weightKg ?? 0)) {
      weightKg = top.weightKg;
      weightReps = top.weightReps;
    }
    if (top.oneRepMaxKg != null && top.oneRepMaxKg! > (oneRepMaxKg ?? 0)) {
      oneRepMaxKg = top.oneRepMaxKg;
    }
    if (top.bodyweightReps != null &&
        top.bodyweightReps! > (bodyweightReps ?? 0)) {
      bodyweightReps = top.bodyweightReps;
    }
  }

  ExerciseBest toExerciseBest(String key) => ExerciseBest(
    exerciseKey: key,
    exerciseName: name,
    exerciseId: exerciseId,
    sessions: sessions,
    lastImprovedAt: lastImprovedAt,
    bestWeightKg: weightKg,
    bestWeightReps: weightReps,
    bestOneRepMaxKg: oneRepMaxKg,
    maxReps: bodyweightReps,
  );
}
