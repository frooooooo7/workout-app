import '../../../../library/domain/models/exercise.dart';
import '../../models/training_session.dart';
import '../../models/training_stats.dart';
import 'stats_sets.dart';

/// Rozkłada ukończone serie na grupy mięśni i partie ciała. Mięsień
/// wymieniony jako pierwszy dostaje całą serię, wspomagające po pół — tak
/// samo jak na mapie mięśni pojedynczej sesji.
///
/// Ranking trzyma grupy tak, jak ćwiczenia są otagowane. Backend zna dla
/// ćwiczeń tylko grupy zbiorcze (plecy, nogi, barki…), więc „Nogi” nie wolno
/// rozdzielać na czworogłowe, dwugłowe i łydki — wyszłyby serie, których nikt
/// nie zrobił. Rozwinięcie na konkretne mięśnie dotyczy wyłącznie mapy ciała
/// ([MuscleDistribution.bodyMap]), gdzie zapala cały region, jak wszędzie
/// indziej w aplikacji.
abstract final class MuscleDistributionCalculator {
  static const _primaryShare = 1.0;
  static const _secondaryShare = 0.5;

  /// Poniżej tylu treningów lista zaniedbanych partii to szum, nie wniosek.
  static const neglectedMinWorkouts = 3;

  /// Mięśnie, o których brak warto ostrzec. Pomijamy te, których ćwiczenia
  /// rzadko są tagowane osobno (prostowniki, romboidalne, przywodziciele,
  /// skośne) oraz przedramiona: backend nie ma dla nich grupy (przy
  /// synchronizacji stają się bicepsem), więc ostrzeżenie świeciłoby na stałe.
  static const keyMuscles = [
    MuscleGroup.chest,
    MuscleGroup.lats,
    MuscleGroup.traps,
    MuscleGroup.frontDelts,
    MuscleGroup.sideDelts,
    MuscleGroup.rearDelts,
    MuscleGroup.biceps,
    MuscleGroup.triceps,
    MuscleGroup.abs,
    MuscleGroup.quads,
    MuscleGroup.hamstrings,
    MuscleGroup.glutes,
    MuscleGroup.calves,
  ];

  static MuscleDistribution compute(Iterable<TrainingSession> sessions) {
    final setsByUnit = <MuscleGroup, double>{};
    final volumeByUnit = <MuscleGroup, double>{};
    final bodySets = <MuscleGroup, double>{};
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

        final muscles = taggedMuscles(exercise);
        final regionShare = <MuscleRegion, double>{};
        for (var i = 0; i < muscles.length; i++) {
          final share = i == 0 ? _primaryShare : _secondaryShare;
          final unit = muscles[i];
          setsByUnit.update(
            unit,
            (v) => v + sets * share,
            ifAbsent: () => sets * share,
          );
          volumeByUnit.update(
            unit,
            (v) => v + volume * share,
            ifAbsent: () => volume * share,
          );
          // Mapa ciała: grupa zbiorcza zapala wszystkie mięśnie regionu.
          for (final muscle in unit.expanded) {
            bodySets.update(
              muscle,
              (v) => v + sets * share,
              ifAbsent: () => sets * share,
            );
          }
          // Partia liczy serię raz, z najwyższym udziałem — ćwiczenie
          // otagowane „najszersze + kaptury” to wciąż jedna seria na plecy.
          final region = unit.region;
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
    if (setsByUnit.isEmpty) return MuscleDistribution.empty;

    final totalSets = setsByUnit.values.fold<double>(0, (a, b) => a + b);
    final maxSets = setsByUnit.values.fold<double>(0, (a, b) => a > b ? a : b);
    final muscles = [
      for (final entry in setsByUnit.entries)
        MuscleStat(
          muscle: entry.key,
          sets: entry.value,
          volumeKg: volumeByUnit[entry.key] ?? 0,
          share: entry.value / totalSets,
          intensity: entry.value / maxSets,
        ),
    ]..sort((a, b) => b.sets.compareTo(a.sets));

    final maxBody = bodySets.values.fold<double>(0, (a, b) => a > b ? a : b);
    final bodyMap = {
      for (final entry in bodySets.entries) entry.key: entry.value / maxBody,
    };

    final regionTotal = setsByRegion.values.fold<double>(0, (a, b) => a + b);
    final regions = [
      for (final entry in setsByRegion.entries)
        RegionStat(
          region: entry.key,
          sets: entry.value,
          share: regionTotal > 0 ? entry.value / regionTotal : 0,
        ),
    ]..sort((a, b) => b.sets.compareTo(a.sets));

    // Mięsień objęty którąkolwiek trenowaną grupą (także zbiorczą) jest
    // „pokryty”: przy tagu „nogi” nie umiemy powiedzieć, że pominięto łydki.
    final covered = {for (final unit in setsByUnit.keys) ...unit.expanded};

    return MuscleDistribution(
      muscles: List.unmodifiable(muscles),
      bodyMap: Map.unmodifiable(bodyMap),
      regions: List.unmodifiable(regions),
      neglected: workouts >= neglectedMinWorkouts
          ? [
              for (final m in keyMuscles)
                if (!covered.contains(m)) m,
            ]
          : const [],
    );
  }
}
