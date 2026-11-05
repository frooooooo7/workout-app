import '../../../library/domain/models/exercise.dart';
import '../models/custom_training_plan.dart';

/// Skrót ćwiczenia w planie w jednej linii: „4 × 8–10 · 60 kg”,
/// „3 × 12/10/8 · 40–50 kg” albo dla kardio „2 odcinki · 20:00”.
///
/// [formatWeight] zamienia zapisany ciężar (kg) na tekst w jednostce konta,
/// [weightUnitLabel] to jej skrót (np. „kg”).
String planExerciseSummary(
  PlanExercise exercise, {
  required String Function(String? rawKg) formatWeight,
  required String weightUnitLabel,
}) {
  final tracking = exercise.exercise.tracking;
  final sets = exercise.sets;
  if (tracking.isCardio) {
    final total = sets.fold<int>(0, (sum, s) => sum + (s.durationSeconds ?? 0));
    final label = cardioSegmentsLabel(sets.length);
    return total > 0 ? '$label · ${formatSetDuration(total)}' : label;
  }

  final parts = <String>[];
  final reps = _distinct([for (final s in sets) s.reps.trim()]);
  if (tracking.tracksReps && reps.isNotEmpty) {
    parts.add(
      reps.length <= 3
          ? '${sets.length} × ${reps.join('/')}'
          : '${sets.length} × ${reps.first}–${reps.last}',
    );
  } else {
    parts.add('${sets.length} ${_setsWord(sets.length)}');
  }

  if (tracking.tracksWeight) {
    final weights = _distinct([
      for (final s in sets)
        if (s.weight != null && s.weight!.trim().isNotEmpty) s.weight!.trim(),
    ]);
    if (weights.isNotEmpty) {
      final shown = weights.map((w) => formatWeight(w)).toList();
      parts.add(
        shown.length == 1
            ? '${shown.first} $weightUnitLabel'
            : '${_extreme(weights, shown, min: true)}–'
                  '${_extreme(weights, shown, min: false)} $weightUnitLabel',
      );
    }
  }
  return parts.join(' · ');
}

String _setsWord(int count) => count == 1 ? 'seria' : 'serie';

List<String> _distinct(List<String> values) {
  final seen = <String>{};
  return [
    for (final v in values)
      if (v.isNotEmpty && seen.add(v)) v,
  ];
}

/// Najmniejszy / największy ciężar (po wartości w kg), w formacie do pokazania.
String _extreme(List<String> raw, List<String> shown, {required bool min}) {
  var best = 0;
  for (var i = 1; i < raw.length; i++) {
    final a = double.tryParse(raw[i].replaceAll(',', '.'));
    final b = double.tryParse(raw[best].replaceAll(',', '.'));
    if (a == null || b == null) continue;
    if (min ? a < b : a > b) best = i;
  }
  return shown[best];
}

/// „Klatka · Barki · Triceps” — główna partia każdego ćwiczenia, bez
/// powtórzeń, najwyżej cztery.
String planMuscleSummary(List<PlanExercise> exercises) {
  final labels = <String>{};
  for (final exercise in exercises) {
    final muscles = exercise.exercise.muscles.where(
      (m) => m != MuscleGroup.all,
    );
    if (muscles.isEmpty) continue;
    labels.add(muscles.first.shortLabel);
    if (labels.length == 4) break;
  }
  return labels.join(' · ');
}
