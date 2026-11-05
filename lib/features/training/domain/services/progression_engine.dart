import '../models/progression_settings.dart';
import '../models/training_session.dart';
import 'training_session_detail_mapper.dart' show parseReps, parseWeightKg;

/// Podpowiedź na serię: ciężar (i przy podwójnej progresji powtórzenia)
/// wyliczone z poprzednich treningów według wybranej metody progresji.
class ProgressionHint {
  const ProgressionHint({
    required this.weightKg,
    required this.deltaKg,
    this.reps,
    this.repsDelta = 0,
    this.isDeload = false,
  });

  final double weightKg;

  /// Zmiana względem poprzedniego treningu: > 0 zwyżka, < 0 deload,
  /// 0 — powtórz ciężar.
  final double deltaKg;

  /// Cel powtórzeń, gdy metoda go zmienia (podwójna progresja); `null` —
  /// powtórzenia z planu.
  final int? reps;

  /// O ile [reps] różni się od poprzedniego razu (`+1`).
  final int repsDelta;

  /// −10 % po serii nieudanych treningów.
  final bool isDeload;

  bool get isIncrease => deltaKg > 0;
  bool get addsReps => repsDelta > 0;
}

const _legMuscles = {'legs', 'glutes', 'quads', 'hamstrings', 'adductors'};

/// Ćwiczenie na nogi lub pośladki (nazwy grup jak w API) — dostaje
/// „większy krok dla nóg”.
bool isLegExercise(Iterable<String> muscles) =>
    muscles.any(_legMuscles.contains);

/// Zakres powtórzeń z planu: `8-12` → (8, 12), `8` → (8, 8); `null` bez liczb.
({int min, int max})? plannedRepRange(String planned) {
  final numbers = RegExp(
    r'\d+',
  ).allMatches(planned).map((m) => int.parse(m.group(0)!)).toList();
  if (numbers.isEmpty) return null;
  final min = numbers.reduce((a, b) => a < b ? a : b);
  final max = numbers.reduce((a, b) => a > b ? a : b);
  return (min: min, max: max);
}

/// Ciężar o jeden krok wyżej według [settings] (w kg). Przy wyłączonej
/// progresji — bez zmiany.
double nextWeightKg(
  double weightKg,
  ProgressionSettings settings, {
  bool legs = false,
}) {
  switch (settings.method) {
    case ProgressionMethod.none:
      return weightKg;
    case ProgressionMethod.percent:
      final unit = settings.unit;
      final increment = settings.step;
      final current = unit.fromKg(weightKg);
      var next =
          (current * (1 + settings.percent / 100) / increment).round() *
          increment;
      if (next <= current + 1e-9) next = current + increment;
      return _clean(unit.toKg(next));
    case ProgressionMethod.fixed:
    case ProgressionMethod.doubleProgression:
    case ProgressionMethod.rir:
      return _clean(weightKg + settings.stepKgFor(legs: legs));
  }
}

/// Ciężar po deloadzie: −10 %, w dół do kroku (najmniejszych krążków).
double deloadWeightKg(double weightKg, ProgressionSettings settings) {
  final unit = settings.unit;
  final increment = settings.step;
  final lowered = unit.fromKg(weightKg) * ProgressionSettings.deloadFactor;
  final rounded = (lowered / increment + 1e-9).floor() * increment;
  return _clean(unit.toKg(rounded > 0 ? rounded : lowered));
}

/// Usuwa ogon zmiennoprzecinkowy (62.50000001 → 62.5).
double _clean(double kg) => (kg * 1000).round() / 1000;

/// Podpowiedź dla serii [current].
///
/// [previous] to pasująca seria z ostatniego treningu tego ćwiczenia,
/// [earlier] — pasujące serie z wcześniejszych treningów, od najnowszego
/// (potrzebne do „zwiększaj po 2 treningach” i deloadu). Rozgrzewki i serie
/// bez poprzedniego ciężaru nie mają podpowiedzi. Cel powtórzeń to górna
/// granica zakresu z planu, a bez planu — wynik z poprzedniego razu.
ProgressionHint? progressionHintFor(
  TrainingSessionSet current,
  TrainingSessionSet? previous, {
  ProgressionSettings settings = ProgressionSettings.off,
  List<TrainingSessionSet?> earlier = const [],
  bool legs = false,
}) {
  if (previous == null || !current.countsTowardStats) return null;
  final weight = parseWeightKg(previous.actualWeight);
  final reps = parseReps(previous.actualReps);
  if (weight == null || weight <= 0 || reps == null) return null;
  if (settings.isOff) return ProgressionHint(weightKg: weight, deltaKg: 0);

  final range = plannedRepRange(current.plannedReps);
  final isDouble =
      settings.method == ProgressionMethod.doubleProgression &&
      range != null &&
      range.min < range.max;
  final target = range?.max ?? reps;

  bool succeeded(TrainingSessionSet set) {
    final setReps = parseReps(set.actualReps);
    if (setReps == null) return false;
    if (settings.method == ProgressionMethod.rir) {
      final rir = parseReps(set.actualRir);
      if (rir != null) return rir >= settings.rirThreshold;
    }
    return setReps >= target;
  }

  bool sameWeight(TrainingSessionSet set) {
    final w = parseWeightKg(set.actualWeight);
    return w != null && (w - weight).abs() < 0.01;
  }

  final history = [previous, ...earlier];

  if (settings.deload &&
      history.length >= ProgressionSettings.deloadAfterFailures) {
    final recent = history.take(ProgressionSettings.deloadAfterFailures);
    final allFailed = recent.every(
      (set) => set != null && sameWeight(set) && !succeeded(set),
    );
    if (allFailed) {
      final lowered = deloadWeightKg(weight, settings);
      return ProgressionHint(
        weightKg: lowered,
        deltaKg: lowered - weight,
        reps: isDouble ? range.min : null,
        isDeload: true,
      );
    }
  }

  var streak = 0;
  for (final set in history) {
    if (set == null || !sameWeight(set) || !succeeded(set)) break;
    streak++;
  }

  if (streak >= settings.sessionsToIncrease) {
    final next = nextWeightKg(weight, settings, legs: legs);
    return ProgressionHint(
      weightKg: next,
      deltaKg: next - weight,
      // Podwójna progresja: po zwyżce powtórzenia wracają na dół zakresu.
      reps: isDouble ? range.min : null,
    );
  }

  if (isDouble && reps < range.max) {
    final nextReps = (reps + 1).clamp(range.min, range.max);
    return ProgressionHint(
      weightKg: weight,
      deltaKg: 0,
      reps: nextReps,
      repsDelta: nextReps - reps,
    );
  }
  return ProgressionHint(weightKg: weight, deltaKg: 0);
}
