import '../../../../library/domain/models/exercise.dart';
import '../../models/training_session.dart';
import '../../models/training_stats.dart';
import 'stats_sets.dart';

/// Rozkłada ukończone serie na mięśnie i partie ciała. Mięsień wymieniony
/// jako pierwszy dostaje całą serię, wspomagające po pół — tak samo jak na
/// mapie mięśni pojedynczej sesji.
abstract final class MuscleDistributionCalculator {
  static const _primaryShare = 1.0;
  static const _secondaryShare = 0.5;

  /// Poniżej tylu treningów lista zaniedbanych partii to szum, nie wniosek.
  static const neglectedMinWorkouts = 3;

  /// Mięśnie, o których brak warto ostrzec. Pomijamy te, których ćwiczenia
  /// rzadko są tagowane osobno (prostowniki, romboidalne, przywodziciele,
  /// skośne), żeby ostrzeżenie nie świeciło przy każdym planie.
  static const keyMuscles = [
    MuscleGroup.chest,
    MuscleGroup.lats,
    MuscleGroup.traps,
    MuscleGroup.frontDelts,
    MuscleGroup.sideDelts,
    MuscleGroup.rearDelts,
    MuscleGroup.biceps,
    MuscleGroup.triceps,
    MuscleGroup.forearms,
    MuscleGroup.abs,
    MuscleGroup.quads,
    MuscleGroup.hamstrings,
    MuscleGroup.glutes,
    MuscleGroup.calves,
  ];

  static MuscleDistribution compute(Iterable<TrainingSession> sessions) {
    final setsByMuscle = <MuscleGroup, double>{};
    final volumeByMuscle = <MuscleGroup, double>{};
    final setsByRegion = <MuscleRegion, double>{};
    var workouts = 0;

    for (final session in sessions) {
      if (session.status != TrainingSessionStatus.completed) continue;
      workouts++;
      for (final exercise in session.exercises) {
        var sets = 0;
        var volume = 0.0;
        for (final set in completedSetsOf(exercise)) {
          sets++;
          volume += set.volumeKg;
        }
        if (sets == 0) continue;

        final muscles = <MuscleGroup>[
          for (final raw in exercise.exerciseMuscles)
            if (MuscleGroup.tryParse(raw) case final m?)
              if (m != MuscleGroup.all) m,
        ];
        final regionShare = <MuscleRegion, double>{};
        for (var i = 0; i < muscles.length; i++) {
          final share = i == 0 ? _primaryShare : _secondaryShare;
          for (final muscle in muscles[i].expanded) {
            setsByMuscle.update(
              muscle,
              (v) => v + sets * share,
              ifAbsent: () => sets * share,
            );
            volumeByMuscle.update(
              muscle,
              (v) => v + volume * share,
              ifAbsent: () => volume * share,
            );
          }
          // Partia liczy serię raz, z najwyższym udziałem — ćwiczenie
          // otagowane „najszersze + kaptury” to wciąż jedna seria na plecy.
          final region = muscles[i].region;
          if (region != null && share > (regionShare[region] ?? 0)) {
            regionShare[region] = share;
          }
        }
        for (final entry in regionShare.entries) {
          setsByRegion.update(
            entry.key,
            (v) => v + sets * entry.value,
            ifAbsent: () => sets * entry.value,
          );
        }
      }
    }

    // Bez otagowanych mięśni nie wiemy nic — to nie znaczy, że wszystko
    // jest zaniedbane.
    if (setsByMuscle.isEmpty) return MuscleDistribution.empty;

    final totalSets = setsByMuscle.values.fold<double>(0, (a, b) => a + b);
    final maxSets = setsByMuscle.values.fold<double>(
      0,
      (a, b) => a > b ? a : b,
    );
    final muscles = [
      for (final entry in setsByMuscle.entries)
        MuscleStat(
          muscle: entry.key,
          sets: entry.value,
          volumeKg: volumeByMuscle[entry.key] ?? 0,
          share: entry.value / totalSets,
          intensity: entry.value / maxSets,
        ),
    ]..sort((a, b) => b.sets.compareTo(a.sets));

    final regionTotal = setsByRegion.values.fold<double>(0, (a, b) => a + b);
    final regions = [
      for (final entry in setsByRegion.entries)
        RegionStat(
          region: entry.key,
          sets: entry.value,
          share: regionTotal > 0 ? entry.value / regionTotal : 0,
        ),
    ]..sort((a, b) => b.sets.compareTo(a.sets));

    return MuscleDistribution(
      muscles: List.unmodifiable(muscles),
      regions: List.unmodifiable(regions),
      neglected: workouts >= neglectedMinWorkouts
          ? [
              for (final m in keyMuscles)
                if (!setsByMuscle.containsKey(m)) m,
            ]
          : const [],
    );
  }
}
