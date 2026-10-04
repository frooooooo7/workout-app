import '../../../../core/units/weight_unit.dart';
import '../models/training_session.dart';

/// Poprzedni wynik ćwiczenia — kolumna „POPRZ.” w treningu na żywo.
abstract interface class PreviousPerformanceRepository {
  /// Ukończone serie tego ćwiczenia z ostatniego zakończonego treningu, w
  /// którym wykonano choć jedną serię roboczą; `null`, gdy ćwiczenia jeszcze
  /// nie robiono. Ćwiczenie rozpoznajemy po identyfikatorze, a gdy go brak
  /// (sesja pobrana z serwera) po nazwie.
  Future<List<TrainingSessionSet>?> lastCompletedSets({
    required String exerciseId,
    required String exerciseName,
  });
}

/// Poprzednia seria pasująca do serii [index] z [current].
///
/// Rozgrzewki dopasowujemy do rozgrzewek, a pozostałe serie do pozostałych
/// (w kolejności), więc dodanie rozgrzewki nie przesuwa porównania serii
/// roboczych. `null`, gdy poprzednio było mniej serii tego rodzaju.
TrainingSessionSet? previousSetFor(
  List<TrainingSessionSet> current,
  int index,
  List<TrainingSessionSet> previous,
) {
  bool isWarmup(TrainingSessionSet set) => set.setType == SetType.warmup;
  final kindIsWarmup = isWarmup(current[index]);
  var ordinal = 0;
  for (var i = 0; i < index; i++) {
    if (isWarmup(current[i]) == kindIsWarmup) ordinal++;
  }
  final sameKind = previous.where((set) => isWarmup(set) == kindIsWarmup);
  if (ordinal >= sameKind.length) return null;
  return sameKind.elementAt(ordinal);
}

/// `82,5×8`, `×12` (bez ciężaru), `60` (bez powtórzeń); `null`, gdy seria nie
/// ma żadnej z liczb. W kg surowy tekst z klawiatury, bez zamiany separatora;
/// w funtach ciężar przeliczony.
String? formatPreviousSet(TrainingSessionSet? set) {
  if (set == null) return null;
  final weight = weightTextForInput(set.actualWeight?.trim());
  final reps = set.actualReps?.trim() ?? '';
  if (weight.isEmpty && reps.isEmpty) return null;
  if (reps.isEmpty) return weight;
  return '$weight×$reps';
}
