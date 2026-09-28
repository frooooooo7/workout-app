import '../../../training/domain/models/training_session.dart';
import '../../../training/domain/services/training_session_detail_mapper.dart'
    show parseReps, parseWeightKg;
import 'exercise.dart';

/// Najlepsza seria jednego treningu — punkt na wykresie progresu.
class ExerciseSessionPoint {
  const ExerciseSessionPoint({
    required this.date,
    required this.topWeightKg,
    required this.estimatedOneRepMaxKg,
    required this.sets,
  });

  final DateTime date;

  /// Najcięższa ukończona seria (0, gdy trening bez ciężaru).
  final double topWeightKg;

  /// Szacowany 1RM wg wzoru Epleya z najlepszej serii treningu.
  final double estimatedOneRepMaxKg;

  /// Ukończone serie tego ćwiczenia w treningu.
  final int sets;
}

/// Twoje wyniki w jednym ćwiczeniu, policzone z ukończonych treningów.
class ExerciseStats {
  const ExerciseStats({
    required this.sessionsCount,
    required this.totalSets,
    required this.totalVolumeKg,
    required this.bestWeightKg,
    required this.bestWeightReps,
    required this.bestEstimatedOneRepMaxKg,
    required this.maxReps,
    required this.lastPerformedAt,
    required this.history,
  });

  static const empty = ExerciseStats(
    sessionsCount: 0,
    totalSets: 0,
    totalVolumeKg: 0,
    bestWeightKg: null,
    bestWeightReps: null,
    bestEstimatedOneRepMaxKg: null,
    maxReps: null,
    lastPerformedAt: null,
    history: [],
  );

  /// Ile treningów zawierało co najmniej jedną ukończoną serię.
  final int sessionsCount;
  final int totalSets;
  final double totalVolumeKg;

  /// Rekord ciężaru i liczba powtórzeń w tej serii.
  final double? bestWeightKg;
  final int? bestWeightReps;

  final double? bestEstimatedOneRepMaxKg;

  /// Najwięcej powtórzeń w jednej serii — rekord dla ćwiczeń bez ciężaru.
  final int? maxReps;

  final DateTime? lastPerformedAt;

  /// Treningi od najstarszego do najnowszego (maks. [historyLimit]).
  final List<ExerciseSessionPoint> history;

  static const historyLimit = 12;

  bool get hasData => sessionsCount > 0;

  bool get hasWeights => bestWeightKg != null && bestWeightKg! > 0;

  /// Szacowany 1RM wg Epleya; dla pojedynczego powtórzenia to sam ciężar.
  static double estimateOneRepMax(double weightKg, int reps) {
    if (weightKg <= 0 || reps <= 0) return 0;
    if (reps == 1) return weightKg;
    return weightKg * (1 + reps / 30);
  }

  /// Czy ćwiczenie z treningu to [exercise]. Sesje pobrane z serwera mogą
  /// nieść identyfikator serwera zamiast lokalnego — wtedy ratuje nas nazwa
  /// (zapisana w sesji jako snapshot).
  static bool matches(TrainingSessionExercise entry, Exercise exercise) {
    if (entry.exerciseId.isNotEmpty && entry.exerciseId == exercise.id) {
      return true;
    }
    return _normalize(entry.exerciseName) == _normalize(exercise.name);
  }

  static String _normalize(String name) => name.trim().toLowerCase();

  static ExerciseStats fromSessions(
    Exercise exercise,
    Iterable<TrainingSession> sessions,
  ) {
    final ordered =
        sessions
            .where((s) => s.status == TrainingSessionStatus.completed)
            .toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    var sessionsCount = 0;
    var totalSets = 0;
    var totalVolume = 0.0;
    double? bestWeight;
    int? bestWeightReps;
    double? bestOneRm;
    int? maxReps;
    DateTime? lastPerformed;
    final history = <ExerciseSessionPoint>[];

    for (final session in ordered) {
      var sessionSets = 0;
      var sessionTopWeight = 0.0;
      var sessionOneRm = 0.0;

      for (final entry in session.exercises) {
        if (!matches(entry, exercise)) continue;
        for (final set in entry.sets) {
          if (!set.completed) continue;
          sessionSets++;
          final weight =
              parseWeightKg(set.actualWeight ?? set.plannedWeight) ?? 0;
          final reps = parseReps(set.actualReps ?? set.plannedReps) ?? 0;
          totalVolume += weight * reps;

          if (reps > 0 && (maxReps == null || reps > maxReps)) maxReps = reps;
          if (weight > sessionTopWeight) sessionTopWeight = weight;
          if (weight > 0 &&
              (bestWeight == null ||
                  weight > bestWeight ||
                  (weight == bestWeight && reps > (bestWeightReps ?? 0)))) {
            bestWeight = weight;
            bestWeightReps = reps > 0 ? reps : null;
          }
          final oneRm = estimateOneRepMax(weight, reps);
          if (oneRm > sessionOneRm) sessionOneRm = oneRm;
        }
      }

      if (sessionSets == 0) continue;
      sessionsCount++;
      totalSets += sessionSets;
      lastPerformed = session.finishedAt ?? session.startedAt;
      if (sessionOneRm > 0 && (bestOneRm == null || sessionOneRm > bestOneRm)) {
        bestOneRm = sessionOneRm;
      }
      history.add(
        ExerciseSessionPoint(
          date: session.startedAt,
          topWeightKg: sessionTopWeight,
          estimatedOneRepMaxKg: sessionOneRm,
          sets: sessionSets,
        ),
      );
    }

    return ExerciseStats(
      sessionsCount: sessionsCount,
      totalSets: totalSets,
      totalVolumeKg: totalVolume,
      bestWeightKg: bestWeight,
      bestWeightReps: bestWeightReps,
      bestEstimatedOneRepMaxKg: bestOneRm,
      maxReps: maxReps,
      lastPerformedAt: lastPerformed,
      history: history.length > historyLimit
          ? history.sublist(history.length - historyLimit)
          : history,
    );
  }

  /// Ile razy każde ćwiczenie pojawiło się w ukończonych treningach — klucze
  /// to identyfikator ćwiczenia z sesji oraz znormalizowana nazwa.
  static ExerciseUsage usage(Iterable<TrainingSession> sessions) {
    final byId = <String, int>{};
    final byName = <String, int>{};
    for (final session in sessions) {
      if (session.status != TrainingSessionStatus.completed) continue;
      final seenIds = <String>{};
      final seenNames = <String>{};
      for (final entry in session.exercises) {
        if (!entry.sets.any((s) => s.completed)) continue;
        if (entry.exerciseId.isNotEmpty && seenIds.add(entry.exerciseId)) {
          byId.update(entry.exerciseId, (v) => v + 1, ifAbsent: () => 1);
        }
        final name = _normalize(entry.exerciseName);
        if (seenNames.add(name)) {
          byName.update(name, (v) => v + 1, ifAbsent: () => 1);
        }
      }
    }
    return ExerciseUsage._(byId, byName);
  }
}

/// Licznik wykonań ćwiczeń — napędza sortowanie „Popularne”.
class ExerciseUsage {
  const ExerciseUsage._(this._byId, this._byName);

  static const empty = ExerciseUsage._({}, {});

  final Map<String, int> _byId;
  final Map<String, int> _byName;

  int countFor(Exercise exercise) {
    final byId = _byId[exercise.id] ?? 0;
    final byName = _byName[ExerciseStats._normalize(exercise.name)] ?? 0;
    return byId > byName ? byId : byName;
  }
}
