import '../../../../library/domain/models/exercise.dart';
import '../../models/training_session.dart';
import '../../models/training_stats.dart';
import 'muscle_distribution_calculator.dart';
import 'stats_sets.dart';

/// Kiedy ostatnio pracowała każda pozycja rankingu mięśni (z całej historii)
/// i ile serii tygodniowo dostaje w oknie zakresu.
///
/// Pozycje są takie jak w rankingu mięśni: grupy zbiorcze zostają zbiorcze.
abstract final class MuscleRecoveryCalculator {
  /// [all] — cała historia (do „ostatnio”), [inWindow] — sesje z okna
  /// (do serii tygodniowo), [windowWeeks] — długość okna w tygodniach.
  static List<MuscleRecoveryStat> compute({
    required Iterable<TrainingSession> all,
    required Iterable<TrainingSession> inWindow,
    required double windowWeeks,
    required DateTime today,
  }) {
    final last = <MuscleGroup, DateTime>{};
    // Kiedy mięsień był ostatnio celem ćwiczenia (nie tylko pomagał).
    final lastAsTarget = <MuscleGroup, DateTime>{};
    for (final session in all) {
      if (session.status != TrainingSessionStatus.completed) continue;
      final day = statsDay(session.startedAt.toLocal());
      _trainedUnits(session).forEach((unit, sets) {
        final seen = last[unit];
        if (seen == null || day.isAfter(seen)) last[unit] = day;
        if (sets.target > 0) {
          final seenTarget = lastAsTarget[unit];
          if (seenTarget == null || day.isAfter(seenTarget)) {
            lastAsTarget[unit] = day;
          }
        }
      });
    }
    // Stare sesje mają grupy zbiorcze („Plecy”), nowe konkretne mięśnie
    // („Najszersze”). Wiersz zbiorczy znika dopiero, gdy każdy kluczowy mięsień
    // grupy (nogi: czworogłowe, dwugłowe i łydki; barki: przedni, boczny i tylny) był celem
    // ćwiczenia nie wcześniej niż ona sama. Jeden mięsień ani samo wspomaganie
    // nie wystarczą: reszta grupy mogła być nietknięta, a wiersz ma o tym
    // mówić.
    for (final group in [...last.keys]) {
      final groupDay = last[group]!;
      final members = group.expanded.difference({group});
      if (members.isEmpty) continue;
      final key = members.intersection(
        MuscleDistributionCalculator.keyMuscles.toSet(),
      );
      final required = key.isEmpty ? members : key;
      final covered = required.every((m) {
        final day = lastAsTarget[m];
        return day != null && !day.isBefore(groupDay);
      });
      if (covered) last.remove(group);
    }
    if (last.isEmpty) return const [];

    final windowSets = <MuscleGroup, double>{};
    for (final session in inWindow) {
      if (session.status != TrainingSessionStatus.completed) continue;
      _trainedUnits(session).forEach((unit, sets) {
        windowSets.update(
          unit,
          (v) => v + sets.total,
          ifAbsent: () => sets.total,
        );
      });
    }

    final weeks = windowWeeks < 1 ? 1.0 : windowWeeks;
    final todayUtc = DateTime.utc(today.year, today.month, today.day);
    final result = [
      for (final entry in last.entries)
        MuscleRecoveryStat(
          muscle: entry.key,
          lastTrainedAt: entry.value,
          daysSince: todayUtc
              .difference(
                DateTime.utc(
                  entry.value.year,
                  entry.value.month,
                  entry.value.day,
                ),
              )
              .inDays
              .clamp(0, 100000),
          setsPerWeek: (windowSets[entry.key] ?? 0) / weeks,
        ),
    ]..sort((a, b) => a.daysSince.compareTo(b.daysSince));
    return List.unmodifiable(result);
  }

  /// Serie sesji na pozycję rankingu; wspomagające po pół, jak w rozkładzie.
  /// [target] to część serii, w której mięsień był celem.
  static Map<MuscleGroup, ({double total, double target})> _trainedUnits(
    TrainingSession session,
  ) {
    final result = <MuscleGroup, ({double total, double target})>{};
    for (final exercise in session.exercises) {
      final sets = completedSetsOf(exercise).length;
      if (sets == 0) continue;
      final muscles = taggedMuscles(exercise);
      for (var i = 0; i < muscles.length; i++) {
        final share = i == 0 ? 1.0 : 0.5;
        final previous = result[muscles[i]];
        result[muscles[i]] = (
          total: (previous?.total ?? 0) + sets * share,
          target: (previous?.target ?? 0) + (i == 0 ? sets : 0),
        );
      }
    }
    return result;
  }
}
