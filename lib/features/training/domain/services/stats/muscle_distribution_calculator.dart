import '../../../../library/domain/models/exercise.dart';
import '../../models/training_session.dart';
import '../../models/training_stats.dart';
import 'stats_sets.dart';

class _SourceTally {
  int sets = 0;
  int targetSets = 0;
  double volumeKg = 0;
}

List<MuscleSource> _sourcesOf(Map<String, _SourceTally>? tallies) {
  if (tallies == null) return const [];
  final sources = [
    for (final entry in tallies.entries)
      MuscleSource(
        exerciseName: entry.key,
        sets: entry.value.sets,
        targetSets: entry.value.targetSets,
        volumeKg: entry.value.volumeKg,
      ),
  ]..sort((a, b) => b.sets.compareTo(a.sets));
  return List.unmodifiable(sources);
}

/// Rozkłada ukończone serie na grupy mięśni i partie ciała. Mięsień
/// wymieniony jako pierwszy dostaje całą serię, wspomagające po pół.
///
/// Ranking trzyma grupy tak, jak ćwiczenia są otagowane. Backend zna dla
/// ćwiczeń tylko grupy zbiorcze (plecy, nogi, barki…), więc „Nogi” nie wolno
/// rozdzielać na czworogłowe, dwugłowe i łydki — wyszłyby serie, których nikt
/// nie zrobił. Rozwinięcie na konkretne mięśnie dotyczy wyłącznie mapy ciała
/// ([MuscleDistribution.bodyMap]), gdzie zapala cały region, jak wszędzie
/// indziej w aplikacji — ale z tą samą liczbą serii co grupa, bez
/// mnożenia jej przez liczbę mięśni regionu.
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
    final setsByRegion = <MuscleRegion, double>{};
    final sourcesByUnit = <MuscleGroup, Map<String, _SourceTally>>{};
    var workouts = 0;
    var taggedSets = 0;

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
        if (muscles.isNotEmpty) taggedSets += sets;
        final regionShare = <MuscleRegion, double>{};
        for (var i = 0; i < muscles.length; i++) {
          final share = i == 0 ? _primaryShare : _secondaryShare;
          final unit = muscles[i];
          final tally = sourcesByUnit
              .putIfAbsent(unit, () => {})
              .putIfAbsent(exercise.exerciseName, _SourceTally.new);
          tally.sets += sets;
          tally.targetSets += i == 0 ? sets : 0;
          tally.volumeKg += volume;
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
          sources: _sourcesOf(sourcesByUnit[entry.key]),
        ),
    ]..sort((a, b) => b.sets.compareTo(a.sets));

    // Mapa ciała: grupa zbiorcza zapala wszystkie mięśnie regionu tym samym
    // poziomem co sama grupa. Gdy mięsień obejmuje kilka grup, liczy się ta
    // z największym poziomem — nie sumujemy, bo wtedy tag „Nogi” świeciłby
    // czterokrotnie mocniej niż pojedyncza łydka.
    final bodyMap = <MuscleGroup, double>{};
    for (final entry in setsByUnit.entries) {
      final level = entry.value / maxSets;
      for (final muscle in entry.key.expanded) {
        if (level > (bodyMap[muscle] ?? 0)) bodyMap[muscle] = level;
      }
    }

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
      taggedSets: taggedSets,
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
