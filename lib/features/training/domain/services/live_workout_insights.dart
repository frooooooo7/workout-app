import '../../../../core/units/weight_unit.dart';
import '../../../library/domain/models/exercise_stats.dart';
import '../models/training_session.dart';
import '../models/training_stats.dart';
import 'cardio_insights.dart';
import 'training_session_detail_mapper.dart' show parseReps, parseWeightKg;

export 'progression_engine.dart';

/// Wskazówki dla treningu na żywo: najlepsza seria poprzedniego treningu,
/// rekord ćwiczenia, podpowiedź progresji i wykrywanie rekordu tuż po
/// odhaczeniu serii — bez czekania na podsumowanie.

/// Wynik serii do pokazania: `92,5 × 6`, `× 12` (bez ciężaru), `60` (bez
/// powtórzeń). Ciężar w aktualnej jednostce, z przecinkiem dziesiętnym.
String? formatSetResult(double? weightKg, int? reps, {WeightUnit? unit}) {
  final hasWeight = weightKg != null && weightKg > 0;
  if (!hasWeight && reps == null) return null;
  final weight = hasWeight ? formatWeightNumber(weightKg, unit: unit) : '';
  if (reps == null) return weight;
  if (!hasWeight) return '× $reps';
  return '$weight × $reps';
}

/// Najlepsza robocza seria z [sets] (ukończone serie poprzedniego treningu):
/// najcięższa, przy remisie z większą liczbą powtórzeń; bez ciężaru — z
/// największą liczbą powtórzeń. `null`, gdy nie ma żadnej liczby.
TrainingSessionSet? topSetOf(Iterable<TrainingSessionSet> sets) {
  TrainingSessionSet? best;
  var bestWeight = -1.0;
  var bestReps = -1;
  for (final set in sets) {
    if (!set.countsTowardStats) continue;
    final weight = parseWeightKg(set.actualWeight) ?? 0;
    final reps = parseReps(set.actualReps) ?? 0;
    if (weight <= 0 && reps <= 0) continue;
    if (weight > bestWeight || (weight == bestWeight && reps > bestReps)) {
      best = set;
      bestWeight = weight;
      bestReps = reps;
    }
  }
  return best;
}

/// Rekord ćwiczenia, który seria w trakcie treningu może pobić. Te same
/// kryteria co [PersonalRecordsCalculator]: cięższa seria, wyższy szacowany
/// 1RM albo — bez ciężaru — więcej powtórzeń.
class ExerciseRecordBaseline {
  const ExerciseRecordBaseline({
    this.weightKg,
    this.weightReps,
    this.oneRepMaxKg,
    this.bodyweightReps,
  });

  /// Rekord z całej historii (statystyki).
  factory ExerciseRecordBaseline.fromBest(ExerciseBest best) =>
      ExerciseRecordBaseline(
        weightKg: best.bestWeightKg,
        weightReps: best.bestWeightReps,
        oneRepMaxKg: best.bestOneRepMaxKg,
        bodyweightReps: best.maxReps,
      );

  /// Zastępczy rekord z poprzedniego treningu, gdy historia jest niedostępna.
  factory ExerciseRecordBaseline.fromSets(Iterable<TrainingSessionSet> sets) {
    var baseline = const ExerciseRecordBaseline();
    for (final set in sets) {
      if (!set.countsTowardStats) continue;
      baseline = baseline._absorb(
        parseWeightKg(set.actualWeight),
        parseReps(set.actualReps),
      );
    }
    return baseline;
  }

  /// Poniżej tej różnicy (kg) 1RM to remis — jak w statystykach.
  static const _oneRepMaxEpsilon = 0.05;

  final double? weightKg;
  final int? weightReps;
  final double? oneRepMaxKg;
  final int? bodyweightReps;

  bool get isEmpty =>
      weightKg == null && oneRepMaxKg == null && bodyweightReps == null;

  /// `92,5 × 6` albo `× 15` (bez ciężaru); `null` bez rekordu.
  String? format({WeightUnit? unit}) => (weightKg ?? 0) > 0
      ? formatSetResult(weightKg, weightReps, unit: unit)
      : formatSetResult(null, bodyweightReps, unit: unit);

  /// Czy seria o tych wartościach bije rekord. Pierwsze wykonanie ćwiczenia
  /// (pusty rekord) nie jest rekordem — tak samo jak w statystykach.
  bool isBeatenBy(double? weightKg, int? reps) {
    if (isEmpty) return false;
    if (weightKg != null && weightKg > 0) {
      if (weightKg > (this.weightKg ?? 0)) return true;
      if (reps == null) return false;
      final oneRm = ExerciseStats.estimateOneRepMax(weightKg, reps);
      return oneRm > (oneRepMaxKg ?? 0) + _oneRepMaxEpsilon;
    }
    // Seria bez ciężaru bije tylko rekord powtórzeń z masą własną — pusty
    // ciężar w ćwiczeniu ze sztangą to raczej niewpisana liczba niż rekord.
    final best = bodyweightReps;
    return best != null && reps != null && reps > best;
  }

  /// O ile seria poprawia rekord: `+2,5 kg`, `+2 powt.`, `e1RM +1,5 kg`;
  /// `null`, gdy go nie bije.
  String? improvementOf(double? weightKg, int? reps, {WeightUnit? unit}) {
    if (!isBeatenBy(weightKg, reps)) return null;
    if (weightKg != null && weightKg > 0) {
      final best = this.weightKg ?? 0;
      if (weightKg > best && best > 0) {
        return '+${formatWeightWithUnit(weightKg - best, unit: unit)}';
      }
      final bestOneRm = oneRepMaxKg ?? 0;
      if (reps == null || bestOneRm <= 0) return null;
      final oneRm = ExerciseStats.estimateOneRepMax(weightKg, reps);
      return 'e1RM +${formatWeightWithUnit(oneRm - bestOneRm, unit: unit)}';
    }
    return '+${reps! - bodyweightReps!} powt.';
  }

  ExerciseRecordBaseline _absorb(double? weightKg, int? reps) {
    var weight = this.weightKg;
    var weightReps = this.weightReps;
    var oneRm = oneRepMaxKg;
    var bodyweight = bodyweightReps;
    if (weightKg != null && weightKg > 0) {
      if (weight == null ||
          weightKg > weight ||
          (weightKg == weight && (reps ?? 0) > (weightReps ?? 0))) {
        weight = weightKg;
        weightReps = reps;
      }
      if (reps != null) {
        final estimate = ExerciseStats.estimateOneRepMax(weightKg, reps);
        if (estimate > (oneRm ?? 0)) oneRm = estimate;
      }
    } else if (reps != null && reps > (bodyweight ?? 0)) {
      bodyweight = reps;
    }
    return ExerciseRecordBaseline(
      weightKg: weight,
      weightReps: weightReps,
      oneRepMaxKg: oneRm,
      bodyweightReps: bodyweight,
    );
  }
}

/// Indeksy ukończonych serii roboczych z [sets], które pobiły rekord.
/// Serie liczą się po kolei: każda kolejna musi pobić także wcześniejsze
/// serie z tego treningu, więc dwa razy ten sam ciężar to jeden rekord.
Set<int> recordSetIndexes(
  ExerciseRecordBaseline? baseline,
  List<TrainingSessionSet> sets,
) {
  if (baseline == null || baseline.isEmpty) return const {};
  var current = baseline;
  final records = <int>{};
  for (var i = 0; i < sets.length; i++) {
    final set = sets[i];
    if (!set.completed || !set.countsTowardStats) continue;
    final weight = parseWeightKg(set.actualWeight);
    final reps = parseReps(set.actualReps);
    if (current.isBeatenBy(weight, reps)) records.add(i);
    current = current._absorb(weight, reps);
  }
  return records;
}

/// Rekord, który musiała pobić seria [index]: [baseline] z historii
/// poprawiony o wcześniejsze ukończone serie robocze tego treningu.
ExerciseRecordBaseline recordBaselineBefore(
  ExerciseRecordBaseline baseline,
  List<TrainingSessionSet> sets,
  int index,
) {
  var current = baseline;
  for (var i = 0; i < index && i < sets.length; i++) {
    final set = sets[i];
    if (!set.completed || !set.countsTowardStats) continue;
    current = current._absorb(
      parseWeightKg(set.actualWeight),
      parseReps(set.actualReps),
    );
  }
  return current;
}

/// Historia ćwiczenia potrzebna w trakcie treningu: serie z poprzedniego
/// treningu (kolumna „Poprzednio”, chip „Ostatnio”, progresja) i rekord.
class ExerciseHistoryInsights {
  const ExerciseHistoryInsights({
    this.previousSets,
    this.earlierSets = const [],
    this.record,
    this.bestPaceSecondsPerKm,
  });

  static const empty = ExerciseHistoryInsights();

  /// `null` — ćwiczenia jeszcze nie robiono (albo historia niedostępna).
  final List<TrainingSessionSet>? previousSets;

  /// Serie z treningów przed [previousSets], od najnowszego (do progresji).
  final List<List<TrainingSessionSet>> earlierSets;
  final ExerciseRecordBaseline? record;

  /// Kardio: najszybsze tempo z całej historii (s/km).
  final int? bestPaceSecondsPerKm;

  /// „Ostatnio” ćwiczenia: dla kardio suma poprzedniego treningu
  /// (`3,2 km · 18:10`), dla reszty najlepsza seria.
  String? lastResult(TrainingSessionExercise exercise, {WeightUnit? unit}) {
    if (!exercise.tracking.tracksDuration) return lastTopSet(unit: unit);
    return formatCardioTotals(
      cardioTotals(previousSets ?? const []),
      exercise.tracking,
      exercise.distanceUnit,
    );
  }

  /// Najlepsza seria z poprzedniego treningu: `92,5 × 6`.
  String? lastTopSet({WeightUnit? unit}) {
    final top = topSetOf(previousSets ?? const []);
    if (top == null) return null;
    return formatSetResult(
      parseWeightKg(top.actualWeight),
      parseReps(top.actualReps),
      unit: unit,
    );
  }
}
