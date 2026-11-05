import '../models/training_session.dart';
import 'cardio_insights.dart';
import 'live_workout_insights.dart' show topSetOf;
import 'stats/stats_sets.dart' show statsExerciseKey;
import 'training_session_detail_mapper.dart'
    show parseReps, parseWeightKg, trainingSessionDetailFromSession;

/// Porównanie świeżo ukończonego treningu z poprzednim — karta „Porównanie
/// z poprzednim” na ekranie podsumowania.
///
/// Cały trening porównujemy z poprzednim treningiem tego samego planu, a każde
/// ćwiczenie z jego ostatnim wykonaniem (te same liczby co kolumna „Poprzednio”
/// w trakcie treningu). Liczymy tylko serie robocze — rozgrzewek nie ma ani
/// w sumach, ani w wynikach ćwiczeń. Wszystko z lokalnej historii, bez sieci.

/// Wynik ćwiczenia względem jego ostatniego wykonania.
enum ExerciseTrend {
  /// Cięższa najlepsza seria, więcej powtórzeń albo dłuższy dystans/czas.
  improved,

  /// Ta sama najlepsza seria.
  same,

  /// Lżejsza najlepsza seria albo mniej powtórzeń.
  worse,

  /// Ćwiczenia nie robiono wcześniej.
  fresh,

  /// Dziś bez żadnej ukończonej serii — nie liczy się do werdyktu.
  skipped,
}

/// Co mówi różnica wyniku ćwiczenia.
enum DeltaKind { weight, reps, distance, duration }

/// Różnica najlepszej serii: [value] dodatnie to poprawa (kg, powtórzenia,
/// metry albo sekundy zależnie od [kind]).
class ResultDelta {
  const ResultDelta(this.kind, this.value);

  final DeltaKind kind;
  final double value;
}

/// Wynik jednej serii (albo, dla kardio, sumy odcinków ćwiczenia). Ciężar
/// zawsze w kilogramach — jednostkę wybiera dopiero widok.
class SetResult {
  const SetResult({this.weightKg, this.reps, this.seconds, this.meters});

  final double? weightKg;
  final int? reps;
  final int? seconds;
  final int? meters;

  bool get hasWeight => (weightKg ?? 0) > 0;

  bool get isEmpty =>
      !hasWeight && reps == null && (seconds ?? 0) == 0 && (meters ?? 0) == 0;

  double get volumeKg => hasWeight && reps != null ? weightKg! * reps! : 0;
}

/// Wiersz rozwinięcia „seria po serii”. [previous] albo [today] bywa `null`,
/// gdy jedna ze stron miała mniej serii.
class SetComparison {
  const SetComparison({
    required this.index,
    this.previous,
    this.today,
    this.direction,
  });

  /// Numer serii roboczej od 1.
  final int index;
  final SetResult? previous;
  final SetResult? today;

  /// Dodatnie — dziś lepiej, ujemne — gorzej, `0` — tak samo; `null`, gdy
  /// brakuje którejś strony albo to kardio (odcinków nie oceniamy osobno).
  final int? direction;
}

class ExerciseComparison {
  const ExerciseComparison({
    required this.key,
    required this.exerciseName,
    required this.tracking,
    required this.distanceUnit,
    required this.trend,
    required this.workingSets,
    required this.completedSets,
    this.today,
    this.previous,
    this.previousDate,
    this.delta,
    this.sets = const [],
    this.todayVolumeKg = 0,
    this.previousVolumeKg = 0,
  });

  final String key;
  final String exerciseName;
  final ExerciseTracking tracking;
  final DistanceUnit distanceUnit;
  final ExerciseTrend trend;

  /// Serie robocze dziś i ile z nich ukończono („0/3 serie”).
  final int workingSets;
  final int completedSets;

  /// Najlepsza seria (kardio: suma odcinków) dziś i ostatnio.
  final SetResult? today;
  final SetResult? previous;

  /// Kiedy ćwiczenie było robione ostatnio (UTC).
  final DateTime? previousDate;

  /// `null` dla „Nowe”, „bez żadnej serii” i „bez zmian”.
  final ResultDelta? delta;

  /// Serie robocze obok siebie (siłowe; kardio — odcinki).
  final List<SetComparison> sets;

  final double todayVolumeKg;
  final double previousVolumeKg;

  bool get isCardio => tracking.isCardio;
}

/// Sumy treningu dziś i poprzednio.
class ComparisonTotals {
  const ComparisonTotals({
    required this.volumeKg,
    required this.previousVolumeKg,
    required this.sets,
    required this.previousSets,
    required this.durationSeconds,
    required this.previousDurationSeconds,
  });

  final double volumeKg;
  final double previousVolumeKg;
  final int sets;
  final int previousSets;
  final int durationSeconds;
  final int previousDurationSeconds;

  double get volumeDeltaKg => volumeKg - previousVolumeKg;
  int get setsDelta => sets - previousSets;
  int get durationDeltaSeconds => durationSeconds - previousDurationSeconds;
}

enum ComparisonVerdictKind {
  /// Progresów co najmniej tyle, co spadków.
  progress,

  /// Wszystko bez zmian.
  same,

  /// Więcej spadków niż progresów.
  worse,
}

class ComparisonVerdict {
  const ComparisonVerdict({
    required this.kind,
    required this.improved,
    required this.same,
    required this.worse,
    required this.fresh,
  });

  final ComparisonVerdictKind kind;
  final int improved;
  final int same;
  final int worse;
  final int fresh;

  /// Porównane ćwiczenia (bez „Nowych” i pominiętych).
  int get compared => improved + same + worse;
}

enum WorkoutComparisonKind {
  /// Jest poprzedni trening tego planu: sumy + ćwiczenia.
  plan,

  /// Pierwszy trening z planu: jedna linijka zamiast karty.
  firstOfPlan,

  /// Trening bez planu: tylko ćwiczenia, każde z datą ostatniego wykonania.
  lastPerformances,
}

class WorkoutComparison {
  const WorkoutComparison({
    required this.kind,
    required this.planName,
    this.previousSessionId,
    this.previousDate,
    this.totals,
    this.exercises = const [],
    this.verdict,
  });

  final WorkoutComparisonKind kind;
  final String planName;

  /// Poprzedni trening planu (do otwarcia z historii) — tylko [WorkoutComparisonKind.plan].
  final String? previousSessionId;
  final DateTime? previousDate;
  final ComparisonTotals? totals;
  final List<ExerciseComparison> exercises;

  /// `null`, gdy żadne ćwiczenie nie ma porównania.
  final ComparisonVerdict? verdict;
}

/// Wejście liczenia w osobnym wątku (długa historia).
typedef WorkoutComparisonInput = ({
  TrainingSession session,
  List<TrainingSession> history,
});

WorkoutComparison? workoutComparisonJob(WorkoutComparisonInput input) =>
    compareWithPrevious(input.session, input.history);

/// Porównuje [session] z poprzednim treningiem planu i ostatnimi wykonaniami
/// ćwiczeń z [history]. Sesja może już być w [history] — jest pomijana.
/// `null`, gdy nie ma czego pokazać (nic nie ukończono albo wszystkie ćwiczenia
/// są nowe, a nie ma poprzedniego treningu planu).
WorkoutComparison? compareWithPrevious(
  TrainingSession session,
  Iterable<TrainingSession> history,
) {
  if (!_hasCompletedWork(session)) return null;

  final earlier = <TrainingSession>[
    for (final s in history)
      if (s.status == TrainingSessionStatus.completed &&
          !_isSameSession(s, session) &&
          s.startedAt.isBefore(session.startedAt) &&
          _hasCompletedWork(s))
        s,
  ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  final isPlanned = session.planLocalId != null || session.planServerId != null;
  final previousPlanSession = isPlanned
      ? earlier.where((s) => _isSamePlan(s, session)).firstOrNull
      : null;

  if (isPlanned && previousPlanSession == null) {
    return WorkoutComparison(
      kind: WorkoutComparisonKind.firstOfPlan,
      planName: session.planName,
    );
  }

  final exercises = _compareExercises(
    session,
    earlier,
    // Trening bez planu: data przy każdym ćwiczeniu, bo to różne treningi.
    withDates: previousPlanSession == null,
  );

  if (previousPlanSession == null) {
    if (exercises.every(
      (e) => e.trend == ExerciseTrend.fresh || e.trend == ExerciseTrend.skipped,
    )) {
      return null;
    }
    return WorkoutComparison(
      kind: WorkoutComparisonKind.lastPerformances,
      planName: session.planName,
      exercises: exercises,
      verdict: _verdictOf(exercises),
    );
  }

  final today = trainingSessionDetailFromSession(session);
  final before = trainingSessionDetailFromSession(previousPlanSession);
  return WorkoutComparison(
    kind: WorkoutComparisonKind.plan,
    planName: session.planName,
    previousSessionId: previousPlanSession.id,
    previousDate: previousPlanSession.startedAt,
    totals: ComparisonTotals(
      volumeKg: today.totalVolumeKg,
      previousVolumeKg: before.totalVolumeKg,
      sets: today.completedSetsCount,
      previousSets: before.completedSetsCount,
      durationSeconds: today.durationSec,
      previousDurationSeconds: before.durationSec,
    ),
    exercises: exercises,
    verdict: _verdictOf(exercises),
  );
}

bool _hasCompletedWork(TrainingSession session) => session.exercises.any(
  (e) => e.sets.any((s) => s.completed && s.countsTowardStats),
);

bool _isSameSession(TrainingSession a, TrainingSession b) =>
    a.id == b.id || (a.serverId != null && a.serverId == b.serverId);

/// Ten sam plan: po identyfikatorze (lokalnym albo z serwera), a gdy któraś ze
/// stron go nie ma — po nazwie. Dwa plany o tej samej nazwie, ale różnych
/// identyfikatorach, to dwa plany.
bool _isSamePlan(TrainingSession candidate, TrainingSession session) {
  final localMatch =
      session.planLocalId != null &&
      session.planLocalId == candidate.planLocalId;
  final serverMatch =
      session.planServerId != null &&
      session.planServerId == candidate.planServerId;
  if (localMatch || serverMatch) return true;

  final name = session.planName.trim().toLowerCase();
  if (name.isEmpty || name == TrainingSession.defaultCustomName.toLowerCase()) {
    return false;
  }
  // Ten sam rodzaj identyfikatora po obu stronach, a różny — to inny plan,
  // nawet przy tej samej nazwie. Gdy jedna strona ma tylko id lokalne, a druga
  // tylko serwerowe (sesja jeszcze niezsynchronizowana), ratuje nazwa.
  if (_idsComparable(candidate, session)) return false;
  return candidate.planName.trim().toLowerCase() == name;
}

/// Czy obie sesje mają ten sam rodzaj identyfikatora planu, więc jego różnica
/// coś znaczy (lokalny vs lokalny albo serwerowy vs serwerowy).
bool _idsComparable(TrainingSession a, TrainingSession b) =>
    (a.planLocalId != null && b.planLocalId != null) ||
    (a.planServerId != null && b.planServerId != null);

/// Serie robocze ukończone z [exercises] danego klucza, w kolejności sesji.
class _ExerciseSets {
  _ExerciseSets(this.exercise);

  final TrainingSessionExercise exercise;
  final List<TrainingSessionSet> working = [];

  List<TrainingSessionSet> get completed => [
    for (final set in working)
      if (set.completed) set,
  ];
}

Map<String, _ExerciseSets> _groupByExercise(TrainingSession session) {
  final grouped = <String, _ExerciseSets>{};
  for (final exercise in session.exercises) {
    final entry = grouped.putIfAbsent(
      statsExerciseKey(exercise),
      () => _ExerciseSets(exercise),
    );
    entry.working.addAll(exercise.sets.where((s) => s.countsTowardStats));
  }
  return grouped;
}

List<ExerciseComparison> _compareExercises(
  TrainingSession session,
  List<TrainingSession> earlier, {
  required bool withDates,
}) {
  final today = _groupByExercise(session);
  final result = <ExerciseComparison>[];
  // Ostatnie wykonanie szukamy od najnowszego; grupowanie sesji robimy raz
  // i tylko dla tych, do których faktycznie zajrzymy.
  final grouped = <TrainingSession, Map<String, _ExerciseSets>>{};

  for (final entry in today.entries) {
    final exercise = entry.value.exercise;
    final tracking = exercise.tracking;
    final doneToday = entry.value.completed;

    TrainingSession? previousSession;
    _ExerciseSets? previousSets;
    for (final candidate in earlier) {
      final sets = (grouped[candidate] ??= _groupByExercise(
        candidate,
      ))[entry.key];
      // Serie odhaczone bez wpisanych liczb nie są wynikiem — szukamy dalej
      // wstecz, zamiast porównywać z „0 kg × 0”.
      if (sets != null && !_bestOf(sets.completed, tracking).isEmpty) {
        previousSession = candidate;
        previousSets = sets;
        break;
      }
    }

    final todayBest = _bestOf(doneToday, tracking);
    // Bez ukończonej serii albo z seriami odhaczonymi bez liczb nie ma wyniku,
    // który dałoby się ocenić.
    if (todayBest.isEmpty) {
      result.add(
        ExerciseComparison(
          key: entry.key,
          exerciseName: exercise.exerciseName,
          tracking: tracking,
          distanceUnit: exercise.distanceUnit,
          trend: ExerciseTrend.skipped,
          workingSets: entry.value.working.length,
          completedSets: doneToday.length,
        ),
      );
      continue;
    }

    if (previousSets == null || previousSession == null) {
      result.add(
        ExerciseComparison(
          key: entry.key,
          exerciseName: exercise.exerciseName,
          tracking: tracking,
          distanceUnit: exercise.distanceUnit,
          trend: ExerciseTrend.fresh,
          workingSets: entry.value.working.length,
          completedSets: doneToday.length,
          today: todayBest,
          todayVolumeKg: _volumeOf(doneToday),
        ),
      );
      continue;
    }

    final previousDone = previousSets.completed;
    final previousBest = _bestOf(previousDone, tracking);
    final comparison = _compareResults(
      todayBest,
      previousBest,
      cardio: tracking,
    );
    final delta = _deltaOf(todayBest, previousBest, tracking);
    result.add(
      ExerciseComparison(
        key: entry.key,
        exerciseName: exercise.exerciseName,
        tracking: tracking,
        distanceUnit: exercise.distanceUnit,
        trend: comparison > 0
            ? ExerciseTrend.improved
            : comparison < 0
            ? ExerciseTrend.worse
            : ExerciseTrend.same,
        workingSets: entry.value.working.length,
        completedSets: doneToday.length,
        today: todayBest,
        previous: previousBest,
        previousDate: previousSession.startedAt,
        delta: comparison == 0 ? null : delta,
        sets: _setRows(previousDone, doneToday, tracking),
        todayVolumeKg: _volumeOf(doneToday),
        previousVolumeKg: _volumeOf(previousDone),
      ),
    );
  }
  return result;
}

double _volumeOf(List<TrainingSessionSet> sets) {
  var total = 0.0;
  for (final set in sets) {
    final weight = parseWeightKg(set.actualWeight);
    final reps = parseReps(set.actualReps);
    if (weight != null && weight > 0 && reps != null) total += weight * reps;
  }
  return total;
}

SetResult _resultOfSet(TrainingSessionSet set) => SetResult(
  weightKg: parseWeightKg(set.actualWeight),
  reps: parseReps(set.actualReps),
  seconds: set.actualDurationSeconds,
  meters: set.actualDistanceM,
);

/// Najlepsza seria — ta sama „top seria” co w chipie „Ostatnio”. Kardio i serie
/// na czas: suma odcinków.
SetResult _bestOf(List<TrainingSessionSet> sets, ExerciseTracking tracking) {
  if (tracking.isCardio) {
    final totals = cardioTotals(sets);
    return SetResult(seconds: totals.seconds, meters: totals.meters);
  }
  final top = topSetOf(sets);
  return top == null ? const SetResult() : _resultOfSet(top);
}

/// Dodatnie, gdy [a] jest lepsze od [b]. Ciężar decyduje przed powtórzeniami
/// (82,5 × 6 po 80 × 8 to progres); kardio — dystans, a bez niego czas.
int _compareResults(SetResult a, SetResult b, {ExerciseTracking? cardio}) {
  if (cardio?.isCardio ?? false) {
    if (cardio!.tracksDistance &&
        ((a.meters ?? 0) > 0 || (b.meters ?? 0) > 0)) {
      return (a.meters ?? 0).compareTo(b.meters ?? 0);
    }
    return (a.seconds ?? 0).compareTo(b.seconds ?? 0);
  }
  return _compareStrength(a, b);
}

int _compareStrength(SetResult a, SetResult b) {
  const epsilon = 0.01;
  final weightA = a.weightKg ?? 0;
  final weightB = b.weightKg ?? 0;
  if ((weightA - weightB).abs() > epsilon) return weightA.compareTo(weightB);
  return (a.reps ?? 0).compareTo(b.reps ?? 0);
}

ResultDelta? _deltaOf(
  SetResult today,
  SetResult previous,
  ExerciseTracking tracking,
) {
  if (tracking.isCardio) {
    if (tracking.tracksDistance &&
        ((today.meters ?? 0) > 0 || (previous.meters ?? 0) > 0)) {
      return ResultDelta(
        DeltaKind.distance,
        ((today.meters ?? 0) - (previous.meters ?? 0)).toDouble(),
      );
    }
    return ResultDelta(
      DeltaKind.duration,
      ((today.seconds ?? 0) - (previous.seconds ?? 0)).toDouble(),
    );
  }
  final weightDelta = (today.weightKg ?? 0) - (previous.weightKg ?? 0);
  if (weightDelta.abs() > 0.01) {
    return ResultDelta(DeltaKind.weight, weightDelta);
  }
  return ResultDelta(
    DeltaKind.reps,
    ((today.reps ?? 0) - (previous.reps ?? 0)).toDouble(),
  );
}

List<SetComparison> _setRows(
  List<TrainingSessionSet> previous,
  List<TrainingSessionSet> today,
  ExerciseTracking tracking,
) {
  final count = previous.length > today.length ? previous.length : today.length;
  return [
    for (var i = 0; i < count; i++)
      SetComparison(
        index: i + 1,
        previous: i < previous.length ? _resultOfSet(previous[i]) : null,
        today: i < today.length ? _resultOfSet(today[i]) : null,
        direction:
            tracking.isCardio || i >= previous.length || i >= today.length
            ? null
            : _compareStrength(
                _resultOfSet(today[i]),
                _resultOfSet(previous[i]),
              ),
      ),
  ];
}

ComparisonVerdict? _verdictOf(List<ExerciseComparison> exercises) {
  var improved = 0;
  var same = 0;
  var worse = 0;
  var fresh = 0;
  for (final e in exercises) {
    switch (e.trend) {
      case ExerciseTrend.improved:
        improved++;
      case ExerciseTrend.same:
        same++;
      case ExerciseTrend.worse:
        worse++;
      case ExerciseTrend.fresh:
        fresh++;
      case ExerciseTrend.skipped:
        break;
    }
  }
  if (improved + same + worse == 0) return null;
  final kind = improved == 0 && worse == 0
      ? ComparisonVerdictKind.same
      : improved >= worse
      ? ComparisonVerdictKind.progress
      : ComparisonVerdictKind.worse;
  return ComparisonVerdict(
    kind: kind,
    improved: improved,
    same: same,
    worse: worse,
    fresh: fresh,
  );
}
