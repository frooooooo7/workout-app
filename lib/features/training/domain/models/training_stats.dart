import '../../../library/domain/models/exercise.dart';
import 'training_summary_stats.dart';

/// Zakres ekranu statystyk.
enum StatsRange {
  week,
  month,
  quarter,
  year,
  all;

  String get label => switch (this) {
    StatsRange.week => '7 dni',
    StatsRange.month => '30 dni',
    StatsRange.quarter => '3 mies.',
    StatsRange.year => 'Rok',
    StatsRange.all => 'Całość',
  };

  /// Podpis porównania w kafelkach („vs poprzednie 7 dni”).
  String get previousLabel => switch (this) {
    StatsRange.week => 'poprzednie 7 dni',
    StatsRange.month => 'poprzednie 30 dni',
    StatsRange.quarter => 'poprzednie 3 mies.',
    StatsRange.year => 'poprzedni rok',
    StatsRange.all => '',
  };
}

/// Szerokość jednego słupka na wykresie w czasie.
enum StatsBucket { day, week, month, year }

/// Przedział czasu `[start, end)` w czasie lokalnym. [previousStart] otwiera
/// okres porównawczy `[previousStart, start)` tej samej długości; `null`, gdy
/// porównanie nie ma sensu (zakres „Całość”).
class StatsWindow {
  const StatsWindow({
    required this.start,
    required this.end,
    required this.bucket,
    this.previousStart,
  });

  final DateTime start;
  final DateTime end;
  final StatsBucket bucket;
  final DateTime? previousStart;

  bool contains(DateTime local) =>
      !local.isBefore(start) && local.isBefore(end);

  bool containsPrevious(DateTime local) {
    final from = previousStart;
    return from != null && !local.isBefore(from) && local.isBefore(start);
  }

  /// Liczba dni kalendarzowych w oknie (bez wrażliwości na zmianę czasu).
  int get days {
    final a = DateTime.utc(start.year, start.month, start.day);
    final b = DateTime.utc(end.year, end.month, end.day);
    return b.difference(a).inDays;
  }
}

/// Jeden słupek wykresu w czasie: sumy z sesji rozpoczętych w `[start, end)`.
class StatsSeriesPoint {
  const StatsSeriesPoint({
    required this.start,
    required this.end,
    this.workouts = 0,
    this.durationSec = 0,
    this.sets = 0,
    this.volumeKg = 0,
  });

  final DateTime start;
  final DateTime end;
  final int workouts;
  final int durationSec;
  final int sets;
  final double volumeKg;
}

/// Dzień na heatmapie aktywności.
class ActivityDay {
  const ActivityDay({
    required this.day,
    this.workouts = 0,
    this.sets = 0,
    this.volumeKg = 0,
  });

  final DateTime day;
  final int workouts;
  final int sets;
  final double volumeKg;
}

/// Heatmapa: pełne tygodnie (od poniedziałku) kończące się bieżącym
/// tygodniem. Dni bez treningu nie mają wpisu w [days].
class StatsActivity {
  const StatsActivity({
    required this.start,
    required this.weeks,
    required this.days,
    required this.today,
  });

  /// Poniedziałek pierwszej kolumny.
  final DateTime start;
  final int weeks;
  final Map<DateTime, ActivityDay> days;
  final DateTime today;

  ActivityDay? dayAt(DateTime day) =>
      days[DateTime(day.year, day.month, day.day)];

  int get trainingDays => days.length;
}

/// Pora dnia rozpoczęcia treningu.
enum TrainingTimeOfDay {
  morning,
  midday,
  evening,
  night;

  String get label => switch (this) {
    TrainingTimeOfDay.morning => 'Rano',
    TrainingTimeOfDay.midday => 'W dzień',
    TrainingTimeOfDay.evening => 'Wieczorem',
    TrainingTimeOfDay.night => 'Nocą',
  };

  String get hours => switch (this) {
    TrainingTimeOfDay.morning => '5–11',
    TrainingTimeOfDay.midday => '11–16',
    TrainingTimeOfDay.evening => '16–21',
    TrainingTimeOfDay.night => '21–5',
  };

  static TrainingTimeOfDay of(DateTime local) {
    final h = local.hour;
    if (h >= 5 && h < 11) return TrainingTimeOfDay.morning;
    if (h >= 11 && h < 16) return TrainingTimeOfDay.midday;
    if (h >= 16 && h < 21) return TrainingTimeOfDay.evening;
    return TrainingTimeOfDay.night;
  }
}

/// Nawyki w oknie: kiedy i jak intensywnie trenujesz.
class TrainingHabits {
  const TrainingHabits({
    required this.weekdayCounts,
    required this.timeOfDayCounts,
    this.avgDurationSec,
    this.avgSetsPerWorkout,
    this.avgRepsPerSet,
    this.avgRir,
    this.workoutsPerWeek,
  });

  /// Indeks 0 = poniedziałek … 6 = niedziela.
  final List<int> weekdayCounts;
  final Map<TrainingTimeOfDay, int> timeOfDayCounts;
  final int? avgDurationSec;
  final double? avgSetsPerWorkout;
  final double? avgRepsPerSet;

  /// Średni RIR ukończonych serii, które go mają.
  final double? avgRir;
  final double? workoutsPerWeek;

  static const empty = TrainingHabits(
    weekdayCounts: [0, 0, 0, 0, 0, 0, 0],
    timeOfDayCounts: {},
  );

  /// [DateTime.weekday] najczęstszego dnia; `null` bez treningów.
  int? get favoriteWeekday {
    var best = -1;
    var bestCount = 0;
    for (var i = 0; i < weekdayCounts.length; i++) {
      if (weekdayCounts[i] > bestCount) {
        best = i;
        bestCount = weekdayCounts[i];
      }
    }
    return best < 0 ? null : best + 1;
  }

  TrainingTimeOfDay? get favoriteTimeOfDay {
    TrainingTimeOfDay? best;
    var bestCount = 0;
    for (final entry in timeOfDayCounts.entries) {
      if (entry.value > bestCount) {
        best = entry.key;
        bestCount = entry.value;
      }
    }
    return best;
  }
}

/// Praca jednego mięśnia w oknie. Serie są ułamkowe: mięsień wymieniony
/// jako pierwszy dostaje całą serię, wspomagające po pół.
class MuscleStat {
  const MuscleStat({
    required this.muscle,
    required this.sets,
    required this.volumeKg,
    required this.share,
    required this.intensity,
  });

  final MuscleGroup muscle;
  final double sets;
  final double volumeKg;

  /// Udział 0..1 w sumie serii wszystkich mięśni.
  final double share;

  /// 0..1 względem najmocniej trenowanego mięśnia — podświetlenie manekina.
  final double intensity;
}

class RegionStat {
  const RegionStat({
    required this.region,
    required this.sets,
    required this.share,
  });

  final MuscleRegion region;
  final double sets;
  final double share;
}

class MuscleDistribution {
  const MuscleDistribution({
    required this.muscles,
    required this.regions,
    required this.neglected,
  });

  /// Od najmocniej trenowanego.
  final List<MuscleStat> muscles;

  /// Od największego udziału.
  final List<RegionStat> regions;

  /// Kluczowe mięśnie bez ani jednej serii w oknie (puste, gdy treningów było
  /// za mało, żeby ostrzeżenie coś znaczyło).
  final List<MuscleGroup> neglected;

  static const empty = MuscleDistribution(
    muscles: [],
    regions: [],
    neglected: [],
  );

  bool get isEmpty => muscles.isEmpty;
}

enum PersonalRecordKind { weight, oneRepMax, reps }

/// Pobity rekord ćwiczenia w jednej sesji.
class PersonalRecord {
  const PersonalRecord({
    required this.exerciseKey,
    required this.exerciseName,
    required this.exerciseId,
    required this.sessionId,
    required this.date,
    required this.kinds,
    this.weightKg,
    this.reps,
    this.oneRepMaxKg,
    this.improvement,
  });

  final String exerciseKey;
  final String exerciseName;
  final String exerciseId;
  final String sessionId;
  final DateTime date;
  final Set<PersonalRecordKind> kinds;

  /// Seria, która dała rekord (dla rekordu powtórzeń — bez ciężaru).
  final double? weightKg;
  final int? reps;
  final double? oneRepMaxKg;

  /// O ile poprawiono poprzedni rekord głównego rodzaju ([primaryKind]):
  /// kg dla ciężaru i 1RM, powtórzenia dla rekordu powtórzeń.
  final double? improvement;

  PersonalRecordKind get primaryKind {
    if (kinds.contains(PersonalRecordKind.weight)) {
      return PersonalRecordKind.weight;
    }
    if (kinds.contains(PersonalRecordKind.oneRepMax)) {
      return PersonalRecordKind.oneRepMax;
    }
    return PersonalRecordKind.reps;
  }
}

/// Najlepsze wyniki ćwiczenia z całej historii.
class ExerciseBest {
  const ExerciseBest({
    required this.exerciseKey,
    required this.exerciseName,
    required this.exerciseId,
    required this.sessions,
    required this.lastImprovedAt,
    this.bestWeightKg,
    this.bestWeightReps,
    this.bestOneRepMaxKg,
    this.maxReps,
  });

  final String exerciseKey;
  final String exerciseName;
  final String exerciseId;
  final int sessions;
  final DateTime lastImprovedAt;
  final double? bestWeightKg;
  final int? bestWeightReps;
  final double? bestOneRepMaxKg;

  /// Najwięcej powtórzeń w serii bez ciężaru.
  final int? maxReps;
}

/// Najlepsza seria ćwiczenia w jednej sesji — punkt wykresu progresu.
class ExerciseProgressPoint {
  const ExerciseProgressPoint({
    required this.date,
    required this.sets,
    required this.volumeKg,
    this.topWeightKg,
    this.oneRepMaxKg,
    this.maxReps,
  });

  final DateTime date;
  final int sets;
  final double volumeKg;
  final double? topWeightKg;
  final double? oneRepMaxKg;
  final int? maxReps;
}

/// Ćwiczenie w oknie: ile razy, ile pracy i jak szedł progres.
class ExerciseProgress {
  const ExerciseProgress({
    required this.exerciseKey,
    required this.exerciseName,
    required this.exerciseId,
    required this.sessions,
    required this.sets,
    required this.volumeKg,
    required this.points,
  });

  final String exerciseKey;
  final String exerciseName;
  final String exerciseId;

  /// Sumy w oknie zakresu.
  final int sessions;
  final int sets;
  final double volumeKg;

  /// Sesje od [TrainingStatsSnapshot.progressFrom], od najstarszej.
  final List<ExerciseProgressPoint> points;

  bool get hasWeights => points.any((p) => (p.oneRepMaxKg ?? 0) > 0);

  /// Zmiana szacowanego 1RM (lub powtórzeń bez ciężaru) między pierwszym
  /// a ostatnim punktem; `null`, gdy punktów jest za mało.
  double? get change {
    if (points.length < 2) return null;
    if (hasWeights) {
      final values = [
        for (final p in points)
          if ((p.oneRepMaxKg ?? 0) > 0) p.oneRepMaxKg!,
      ];
      if (values.length < 2) return null;
      return values.last - values.first;
    }
    final reps = [
      for (final p in points)
        if (p.maxReps != null) p.maxReps!,
    ];
    if (reps.length < 2) return null;
    return (reps.last - reps.first).toDouble();
  }
}

/// Komplet statystyk dla jednego zakresu.
class TrainingStatsSnapshot {
  const TrainingStatsSnapshot({
    required this.range,
    required this.window,
    required this.current,
    required this.previous,
    required this.trainingDays,
    required this.recordsCount,
    required this.previousRecordsCount,
    required this.currentStreakWeeks,
    required this.bestStreakWeeks,
    required this.series,
    required this.activity,
    required this.habits,
    required this.muscles,
    required this.records,
    required this.bests,
    required this.exercises,
    required this.progressFrom,
    required this.hasHistory,
  });

  final StatsRange range;
  final StatsWindow window;
  final TrainingPeriodStats current;

  /// `null` dla zakresu bez porównania.
  final TrainingPeriodStats? previous;
  final int trainingDays;
  final int recordsCount;
  final int? previousRecordsCount;
  final int currentStreakWeeks;
  final int bestStreakWeeks;
  final List<StatsSeriesPoint> series;
  final StatsActivity activity;
  final TrainingHabits habits;
  final MuscleDistribution muscles;

  /// Rekordy pobite w oknie, najnowsze najpierw.
  final List<PersonalRecord> records;

  /// Najlepsze wyniki wszystkich ćwiczeń, ostatnio poprawione najpierw.
  final List<ExerciseBest> bests;

  /// Najczęściej wykonywane ćwiczenia w oknie.
  final List<ExerciseProgress> exercises;

  /// Początek wykresu progresu — co najmniej 3 miesiące wstecz, bo w tygodniu
  /// progresu nie widać.
  final DateTime progressFrom;

  /// Czy użytkownik ma jakikolwiek ukończony trening (poza oknem też).
  final bool hasHistory;

  bool get isEmpty => current.workouts == 0;
}
