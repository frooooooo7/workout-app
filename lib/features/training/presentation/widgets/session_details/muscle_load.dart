import '../../../../library/domain/models/exercise.dart';
import '../../../domain/models/training_history_models.dart';

/// Udział mięśnia wymienionego jako pierwszy na liście ćwiczenia. Kolejne
/// traktujemy jako wspomagające i liczymy z połową wagi — inaczej ćwiczenie
/// wielostawowe zapalałoby trzy partie tak samo mocno jak izolacja jedną.
const double _primaryShare = 1.0;
const double _secondaryShare = 0.5;

class MuscleLoad {
  const MuscleLoad({
    required this.muscle,
    required this.volumeKg,
    required this.sets,
    required this.intensity,
    required this.share,
  });

  final MuscleGroup muscle;

  /// Objętość przypisana mięśniowi po zastosowaniu udziałów.
  final double volumeKg;

  /// Liczba ukończonych serii, które dotknęły tego mięśnia.
  final int sets;

  /// Znormalizowane obciążenie 0..1 względem najmocniej obciążonego mięśnia
  /// tej sesji. Napędza wyłącznie podświetlenie manekina (kolor "temperatury") —
  /// liderowi zawsze przypada pełna intensywność, niezależnie ile innych partii
  /// pracowało.
  final double intensity;

  /// Udział 0..1 w łącznej objętości (lub liczbie serii, gdy sesja nie ma
  /// zalogowanych ciężarów) całej sesji. Wszystkie udziały sumują się do 1 —
  /// to właśnie ta wartość jest pokazywana jako "%" w rankingu, bo realnie
  /// odpowiada na pytanie "jaki procent dzisiejszej pracy poszedł w ten mięsień".
  final double share;

  int get percent => (share * 100).round();
}

/// Rozkłada objętość sesji na poszczególne mięśnie.
///
/// Grupy zbiorcze (`plecy`, `nogi`, `barki`) rozwijają się przez
/// [MuscleGroup.expanded] na wszystkie mięśnie swojego regionu — zapisane
/// ćwiczenie nie niesie informacji, który dokładnie mięsień pracował, więc
/// zapalamy cały region zamiast zgadywać.
///
/// Gdy sesja nie ma zalogowanych ciężarów (trening z masą własną), objętość
/// wychodzi zerowa i normalizacja przełącza się na liczbę serii.
List<MuscleLoad> computeMuscleLoads(TrainingSessionDetail detail) {
  final volumeByMuscle = <MuscleGroup, double>{};
  final setsByMuscle = <MuscleGroup, int>{};

  for (final exercise in detail.exercises) {
    final completedSets = exercise.completedSetsCount;
    if (exercise.muscles.isEmpty || completedSets == 0) continue;

    final exerciseVolume = exercise.volumeKg;

    for (var i = 0; i < exercise.muscles.length; i++) {
      final share = i == 0 ? _primaryShare : _secondaryShare;
      for (final muscle in exercise.muscles[i].expanded) {
        volumeByMuscle.update(
          muscle,
          (value) => value + exerciseVolume * share,
          ifAbsent: () => exerciseVolume * share,
        );
        setsByMuscle.update(
          muscle,
          (value) => value + completedSets,
          ifAbsent: () => completedSets,
        );
      }
    }
  }

  if (setsByMuscle.isEmpty) return const [];

  final totalVolume = volumeByMuscle.values.fold<double>(0, (a, b) => a + b);
  final useVolume = totalVolume > 0;

  double weightOf(MuscleGroup m) =>
      useVolume ? (volumeByMuscle[m] ?? 0) : (setsByMuscle[m] ?? 0).toDouble();

  final maxWeight = setsByMuscle.keys
      .map(weightOf)
      .fold<double>(0, (a, b) => a > b ? a : b);
  final totalWeight = setsByMuscle.keys
      .map(weightOf)
      .fold<double>(0, (a, b) => a + b);

  final loads = setsByMuscle.keys.map((muscle) {
    return MuscleLoad(
      muscle: muscle,
      volumeKg: volumeByMuscle[muscle] ?? 0,
      sets: setsByMuscle[muscle] ?? 0,
      intensity: maxWeight > 0 ? weightOf(muscle) / maxWeight : 0,
      share: totalWeight > 0 ? weightOf(muscle) / totalWeight : 0,
    );
  }).toList();

  loads.sort((a, b) => b.intensity.compareTo(a.intensity));
  return List.unmodifiable(loads);
}
