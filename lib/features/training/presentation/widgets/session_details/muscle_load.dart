import '../../../../library/domain/models/exercise.dart';
import '../../../domain/models/training_history_models.dart';
import '../../../domain/models/training_stats.dart' show MuscleSource;

/// Rola mięśnia w sesji: czy był celem treningu, czy tylko pomagał.
enum MuscleRole { primary, secondary }

/// Mięsień jest „główny”, jeśli jako pierwszy tag ćwiczeń dostał co najmniej
/// tę część serii lidera. Odsiewa pojedynczą serię izolacji, która nie robi
/// z mięśnia celu całego treningu.
const double primaryMinShareOfLeader = 0.25;

class MuscleLoad {
  const MuscleLoad({
    required this.muscle,
    required this.role,
    required this.sets,
    required this.volumeKg,
    required this.primarySets,
    required this.sources,
  });

  /// Grupa tak, jak otagowano ćwiczenia („Plecy”, „Biceps”). Grupy zbiorcze
  /// zostają zbiorcze: tag nie mówi, który mięsień regionu pracował, więc nie
  /// zgadujemy i nie dzielimy ich na procenty.
  final MuscleGroup muscle;

  final MuscleRole role;

  /// Liczba ukończonych serii ćwiczeń, które miały ten mięsień w tagach.
  final int sets;

  /// Objętość tych ćwiczeń (bez ważenia). Mięśnie dzielące ćwiczenie liczą ją
  /// każdy w całości, więc nie sumuje się jej między mięśniami.
  final double volumeKg;

  /// Serie, w których mięsień był celem (pierwszym tagiem ćwiczenia).
  final int primarySets;

  /// Ćwiczenia, z których bierze się ten mięsień, od największej liczby serii.
  final List<MuscleSource> sources;

  bool get isPrimary => role == MuscleRole.primary;
}

/// Najkrótsze wyjaśnienie, dlaczego mięsień dostał taką rolę — pokazywane
/// użytkownikowi pod mapą, żeby wiedział, skąd się to bierze.
String muscleRoleReason(MuscleLoad load, {required int leaderPrimarySets}) {
  if (load.isPrimary) {
    return 'Główny: był celem ćwiczenia w ${load.primarySets} '
        '${_plural(load.primarySets)}.';
  }
  if (load.primarySets == 0) {
    return 'Wspomagający: w żadnym ćwiczeniu nie był na pierwszym miejscu '
        'listy mięśni, tylko pomagał.';
  }
  final needed = (leaderPrimarySets * primaryMinShareOfLeader).ceil();
  return 'Wspomagający: był celem tylko w ${load.primarySets} '
      '${_plural(load.primarySets)}, a do głównych trzeba co najmniej '
      '$needed.';
}

String _plural(int n) {
  if (n == 1) return 'serii';
  return 'seriach';
}

/// Dzieli mięśnie sesji na główne i wspomagające.
///
/// Pierwszy tag ćwiczenia to jego cel, kolejne wspomagają. Mięsień jest
/// główny, gdy był celem w co najmniej jednym ćwiczeniu i zebrał co najmniej
/// [primaryMinShareOfLeader] serii „celowych” lidera; pozostałe wspomagają.
///
/// Wynik: najpierw główne, w obu grupach od największej liczby serii.
List<MuscleLoad> computeMuscleLoads(TrainingSessionDetail detail) {
  final setsByMuscle = <MuscleGroup, int>{};
  final primarySetsByMuscle = <MuscleGroup, int>{};
  final volumeByMuscle = <MuscleGroup, double>{};
  final sourcesByMuscle = <MuscleGroup, List<MuscleSource>>{};

  for (final exercise in detail.exercises) {
    final completedSets = exercise.completedSetsCount;
    if (exercise.muscles.isEmpty || completedSets == 0) continue;

    final exerciseVolume = exercise.volumeKg;
    final seen = <MuscleGroup>{};
    for (var i = 0; i < exercise.muscles.length; i++) {
      final muscle = exercise.muscles[i];
      // Ten sam tag dwa razy w jednym ćwiczeniu to wciąż jedna praca.
      if (muscle == MuscleGroup.all || !seen.add(muscle)) continue;
      setsByMuscle.update(
        muscle,
        (v) => v + completedSets,
        ifAbsent: () => completedSets,
      );
      volumeByMuscle.update(
        muscle,
        (v) => v + exerciseVolume,
        ifAbsent: () => exerciseVolume,
      );
      sourcesByMuscle
          .putIfAbsent(muscle, () => [])
          .add(
            MuscleSource(
              exerciseName: exercise.exerciseName,
              sets: completedSets,
              targetSets: i == 0 ? completedSets : 0,
              volumeKg: exerciseVolume,
            ),
          );
      if (i == 0) {
        primarySetsByMuscle.update(
          muscle,
          (v) => v + completedSets,
          ifAbsent: () => completedSets,
        );
      }
    }
  }

  if (setsByMuscle.isEmpty) return const [];

  final leaderPrimarySets = primarySetsByMuscle.values.fold<int>(
    0,
    (a, b) => a > b ? a : b,
  );

  MuscleRole roleOf(MuscleGroup muscle) {
    final primarySets = primarySetsByMuscle[muscle] ?? 0;
    return primarySets > 0 &&
            primarySets >= leaderPrimarySets * primaryMinShareOfLeader
        ? MuscleRole.primary
        : MuscleRole.secondary;
  }

  final loads =
      [
        for (final entry in setsByMuscle.entries)
          MuscleLoad(
            muscle: entry.key,
            role: roleOf(entry.key),
            sets: entry.value,
            volumeKg: volumeByMuscle[entry.key] ?? 0,
            primarySets: primarySetsByMuscle[entry.key] ?? 0,
            sources: List.unmodifiable(
              (sourcesByMuscle[entry.key] ?? const <MuscleSource>[]).toList()
                ..sort((a, b) => b.sets.compareTo(a.sets)),
            ),
          ),
      ]..sort((a, b) {
        if (a.role != b.role) return a.isPrimary ? -1 : 1;
        final bySets = b.sets.compareTo(a.sets);
        // Remis rozstrzyga kolejność enuma — wynik nie zależy od kolejności ćwiczeń.
        return bySets != 0 ? bySets : a.muscle.index.compareTo(b.muscle.index);
      });
  return List.unmodifiable(loads);
}
