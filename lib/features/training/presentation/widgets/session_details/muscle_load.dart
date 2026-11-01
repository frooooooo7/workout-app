import '../../../../library/domain/models/exercise.dart';
import '../../../domain/models/training_history_models.dart';
import '../../../domain/models/training_stats.dart' show MuscleSource;
import '../../../domain/services/muscle_roles.dart';

export '../../../domain/models/muscle_role.dart' show MuscleRole;

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

  /// Serie, w których mięsień był celem (pierwszym tagiem ćwiczenia z
  /// obciążeniem lub powtórzeniami).
  final int primarySets;

  /// Ćwiczenia, z których bierze się ten mięsień, od największej liczby serii.
  final List<MuscleSource> sources;

  bool get isPrimary => role == MuscleRole.primary;
}

/// Dzieli mięśnie sesji na główne i wspomagające (reguły w `muscle_roles.dart`,
/// wspólne ze statystykami okresu).
///
/// Ćwiczenia o tej samej nazwie składają się w jedno źródło.
///
/// Wynik: najpierw główne, w obu grupach od największej liczby serii.
List<MuscleLoad> computeMuscleLoads(TrainingSessionDetail detail) {
  final setsByMuscle = <MuscleGroup, int>{};
  final targetSetsByMuscle = <MuscleGroup, int>{};
  final volumeByMuscle = <MuscleGroup, double>{};
  final sourcesByMuscle = <MuscleGroup, Map<String, MuscleSource>>{};

  final hasRepBasedWork = detail.exercises.any(
    (e) => e.completedSetsCount > 0 && !e.tracking.isCardio,
  );

  for (final exercise in detail.exercises) {
    final completedSets = exercise.completedSetsCount;
    final tags = distinctMuscleTags(exercise.muscles);
    if (tags.isEmpty || completedSets == 0) continue;

    final exerciseVolume = exercise.volumeKg;
    final firstIsTarget = targetsItsFirstMuscle(
      exercise.tracking,
      hasRepBasedWork: hasRepBasedWork,
    );
    for (var i = 0; i < tags.length; i++) {
      final muscle = tags[i];
      final targetSets = i == 0 && firstIsTarget ? completedSets : 0;
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
      targetSetsByMuscle.update(
        muscle,
        (v) => v + targetSets,
        ifAbsent: () => targetSets,
      );
      final sources = sourcesByMuscle.putIfAbsent(muscle, () => {});
      final key = muscleSourceKey(exercise.exerciseName);
      final previous = sources[key];
      sources[key] = MuscleSource(
        exerciseName: previous?.exerciseName ?? exercise.exerciseName,
        sets: (previous?.sets ?? 0) + completedSets,
        targetSets: (previous?.targetSets ?? 0) + targetSets,
        volumeKg: (previous?.volumeKg ?? 0) + exerciseVolume,
      );
    }
  }

  if (setsByMuscle.isEmpty) return const [];

  final roles = assignMuscleRoles(targetSetsByMuscle, setsByMuscle.keys);
  final loads = [
    for (final entry in setsByMuscle.entries)
      MuscleLoad(
        muscle: entry.key,
        role: roles[entry.key]!,
        sets: entry.value,
        volumeKg: volumeByMuscle[entry.key] ?? 0,
        primarySets: targetSetsByMuscle[entry.key] ?? 0,
        sources: List.unmodifiable(
          sourcesByMuscle[entry.key]!.values.toList()
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
