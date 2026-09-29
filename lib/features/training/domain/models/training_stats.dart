import '../../../library/domain/models/exercise.dart';
import 'training_summary_stats.dart';

/// Zakres ekranu statystyk.
enum StatsRange {
  week,
  month,
  quarter,
  year,
  all,

  /// Zakres wybrany z kalendarza — daty niesie [StatsDateRange].
  custom;

  /// Zakresy z paska; [custom] ma własny przycisk z kalendarzem.
  static const presets = [week, month, quarter, year, all];

  String get label => switch (this) {
    StatsRange.week => '7 dni',
    StatsRange.month => '30 dni',
    StatsRange.quarter => '3 mies.',
    StatsRange.year => 'Rok',
    StatsRange.all => 'Całość',
    StatsRange.custom => 'Własny',
  };

  /// Podpis porównania w kafelkach („vs poprzednie 7 dni”).
  String get previousLabel => switch (this) {
    StatsRange.week => 'poprzednie 7 dni',
    StatsRange.month => 'poprzednie 30 dni',
    StatsRange.quarter => 'poprzednie 3 mies.',
    StatsRange.year => 'poprzedni rok',
    StatsRange.all => '',
    StatsRange.custom => 'poprzedni okres',
  };
}

/// Dni wybrane z kalendarza, oba końce włącznie (same daty, bez godzin).
class StatsDateRange {
  StatsDateRange(DateTime a, DateTime b)
    : start = DateTime(a.year, a.month, a.day),
      end = DateTime(b.year, b.month, b.day) {
    assert(!end.isBefore(start), 'end before start');
  }

  final DateTime start;
  final DateTime end;

  /// Liczba dni kalendarzowych (włącznie z oboma końcami).
  int get days =>
      DateTime.utc(
        end.year,
        end.month,
        end.day,
      ).difference(DateTime.utc(start.year, start.month, start.day)).inDays +
      1;

  @override
  bool operator ==(Object other) =>
      other is StatsDateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Szerokość jednego słupka na wykresie w czasie.
enum StatsBucket { day, week, month, year }

/// Przedział czasu `[start, end)` w czasie lokalnym. [previousStart] otwiera
/// okres porównawczy; `null`, gdy porównanie nie ma sensu (zakres „Całość”).
///
/// Okres porównawczy kończy się w [previousEnd] (domyślnie w [start]). Gdy
/// bieżące okno sięga w przyszłość (nieskończony tydzień albo miesiąc),
/// porównujemy tyle samo dni od początku poprzedniego okresu — inaczej
/// niepełny okres wychodziłby zawsze na minus względem pełnego.
class StatsWindow {
  const StatsWindow({
    required this.start,
    required this.end,
    required this.bucket,
    this.previousStart,
    this.previousEnd,
  });

  final DateTime start;
  final DateTime end;
  final StatsBucket bucket;
  final DateTime? previousStart;
  final DateTime? previousEnd;

  bool contains(DateTime local) =>
      !local.isBefore(start) && local.isBefore(end);

  bool containsPrevious(DateTime local) {
    final from = previousStart;
    return from != null &&
        !local.isBefore(from) &&
        local.isBefore(previousEnd ?? start);
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
    this.sessions = const [],
  });

  final DateTime day;
  final int workouts;
  final int sets;
  final double volumeKg;

  /// Sesje tego dnia, od najwcześniejszej — do otwarcia ze szczegółami.
  final List<ActivitySession> sessions;
}

/// Sesja w podsumowaniu dnia na heatmapie.
class ActivitySession {
  const ActivitySession({
    required this.id,
    required this.name,
    required this.startedAt,
  });

  final String id;

  /// Nazwa planu.
  final String name;
  final DateTime startedAt;
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
/// Praca jednej pozycji rankingu. Pozycją jest grupa tak, jak ćwiczenie jest
/// otagowane: zbiorcze („Nogi”, „Plecy”, „Barki”) zostają zbiorcze — nie
/// wiemy, który konkretnie mięsień pracował, więc nie zgadujemy.
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

  /// 0..1 względem najmocniej trenowanej pozycji rankingu.
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
    this.bodyMap = const {},
  });

  /// Od najmocniej trenowanej pozycji.
  final List<MuscleStat> muscles;

  /// Podświetlenie manekina: konkretne mięśnie (grupy zbiorcze rozwinięte na
  /// mięśnie swojego regionu) → 0..1 względem najmocniej podświetlonego.
  final Map<MuscleGroup, double> bodyMap;

  /// Od największego udziału.
  final List<RegionStat> regions;

  /// Kluczowe mięśnie bez ani jednej serii w oknie (puste, gdy treningów było
  /// za mało, żeby ostrzeżenie coś znaczyło). Mięsień objęty grupą zbiorczą
  /// (np. łydki przy tagu „nogi”) liczy się jako trenowany — nie da się
  /// stwierdzić, że go pominięto.
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

/// Tydzień celu tygodniowego.
class GoalWeek {
  const GoalWeek({required this.start, required this.workouts});

  /// Poniedziałek.
  final DateTime start;
  final int workouts;
}

/// Postęp względem celu z profilu („ile treningów w tygodniu”).
class WeeklyGoalProgress {
  const WeeklyGoalProgress({
    required this.goal,
    required this.workoutsThisWeek,
    required this.weeks,
    required this.streakWeeks,
    required this.bestStreakWeeks,
    required this.daysLeft,
  });

  final int goal;
  final int workoutsThisWeek;

  /// Ostatnie tygodnie (najstarszy pierwszy, bieżący ostatni).
  final List<GoalWeek> weeks;

  /// Kolejne tygodnie z wykonanym celem — od bieżącego, a gdy ten jeszcze
  /// nie jest wykonany, od poprzedniego.
  final int streakWeeks;
  final int bestStreakWeeks;

  /// Dni do końca tygodnia (0 w niedzielę), z dzisiejszym nieliczonym.
  final int daysLeft;

  bool get met => workoutsThisWeek >= goal;
  int get remaining => met ? 0 : goal - workoutsThisWeek;

  /// Czy w pozostałych dniach da się jeszcze zrobić brakujące treningi.
  bool get reachable => remaining <= daysLeft + 1;

  int get weeksMet => weeks.where((w) => w.workouts >= goal).length;
}

enum RepRange {
  strength,
  hypertrophy,
  endurance;

  String get label => switch (this) {
    RepRange.strength => 'Siła',
    RepRange.hypertrophy => 'Masa',
    RepRange.endurance => 'Wytrzymałość',
  };

  String get reps => switch (this) {
    RepRange.strength => '1–5',
    RepRange.hypertrophy => '6–12',
    RepRange.endurance => '13+',
  };

  static RepRange of(int reps) {
    if (reps <= 5) return RepRange.strength;
    if (reps <= 12) return RepRange.hypertrophy;
    return RepRange.endurance;
  }
}

/// Ukończone serie z podaną liczbą powtórzeń, w trzech zakresach.
class RepRangeDistribution {
  const RepRangeDistribution({
    this.strength = 0,
    this.hypertrophy = 0,
    this.endurance = 0,
  });

  final int strength;
  final int hypertrophy;
  final int endurance;

  static const empty = RepRangeDistribution();

  int get total => strength + hypertrophy + endurance;

  int setsOf(RepRange range) => switch (range) {
    RepRange.strength => strength,
    RepRange.hypertrophy => hypertrophy,
    RepRange.endurance => endurance,
  };

  /// Udział 0..1; 0, gdy nie ma serii.
  double shareOf(RepRange range) => total == 0 ? 0 : setsOf(range) / total;

  /// Zakres z największym udziałem; `null` bez serii.
  RepRange? get dominant {
    if (total == 0) return null;
    return RepRange.values.reduce((a, b) => setsOf(b) > setsOf(a) ? b : a);
  }
}

enum SessionRecordKind { volume, duration, sets }

/// Rekord jednej sesji z całej historii.
class SessionRecord {
  const SessionRecord({
    required this.kind,
    required this.value,
    required this.sessionId,
    required this.name,
    required this.date,
  });

  final SessionRecordKind kind;

  /// kg dla objętości, sekundy dla czasu, liczba serii.
  final double value;
  final String sessionId;

  /// Nazwa planu sesji.
  final String name;
  final DateTime date;
}

/// Tydzień z największą objętością.
class BestWeek {
  const BestWeek({
    required this.start,
    required this.volumeKg,
    required this.workouts,
  });

  final DateTime start;
  final double volumeKg;
  final int workouts;
}

class SessionRecords {
  const SessionRecords({this.records = const [], this.bestWeek});

  static const empty = SessionRecords();

  /// W kolejności [SessionRecordKind]; brak wpisu, gdy nie ma z czego liczyć
  /// (np. objętości przy treningach bez ciężarów).
  final List<SessionRecord> records;
  final BestWeek? bestWeek;

  SessionRecord? of(SessionRecordKind kind) {
    for (final r in records) {
      if (r.kind == kind) return r;
    }
    return null;
  }

  bool get isEmpty => records.isEmpty && bestWeek == null;
}

/// Kiedy ostatnio pracowała dana pozycja rankingu mięśni.
class MuscleRecoveryStat {
  const MuscleRecoveryStat({
    required this.muscle,
    required this.lastTrainedAt,
    required this.daysSince,
    required this.setsPerWeek,
  });

  final MuscleGroup muscle;

  /// Z całej historii, nie tylko z okna.
  final DateTime lastTrainedAt;
  final int daysSince;

  /// Średnia liczba serii tygodniowo w oknie zakresu (0, gdy w oknie nie
  /// pracował).
  final double setsPerWeek;
}

enum StatsInsightKind {
  inactivity,
  goalMet,
  goalBehind,
  volumeUp,
  volumeDown,
  records,
  plateau,
  progress,
  neglected,
  streak,
}

enum StatsInsightTone { positive, neutral, attention }

/// Krótki wniosek z danych („Objętość wzrosła o 12%”).
class StatsInsight {
  const StatsInsight({
    required this.kind,
    required this.tone,
    required this.text,
    this.exerciseId,
  });

  final StatsInsightKind kind;
  final StatsInsightTone tone;
  final String text;

  /// Ćwiczenie, do którego wniosek się odnosi — pozwala otworzyć jego
  /// szczegóły.
  final String? exerciseId;
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
    this.customRange,
    this.goal,
    this.repRanges = RepRangeDistribution.empty,
    this.sessionRecords = SessionRecords.empty,
    this.recovery = const [],
    this.insights = const [],
    this.daysSinceLastWorkout,
  });

  final StatsRange range;

  /// Daty zakresu [StatsRange.custom]; w pozostałych `null`.
  final StatsDateRange? customRange;
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

  /// `null`, gdy w profilu nie ma celu tygodniowego (albo jeszcze się nie
  /// wczytał).
  final WeeklyGoalProgress? goal;
  final RepRangeDistribution repRanges;

  /// Z całej historii, niezależne od zakresu.
  final SessionRecords sessionRecords;

  /// Od ostatnio trenowanej pozycji; z całej historii.
  final List<MuscleRecoveryStat> recovery;

  /// Najważniejsze wnioski, najpilniejszy pierwszy.
  final List<StatsInsight> insights;

  /// Pełne dni od ostatniego treningu; `null` bez historii.
  final int? daysSinceLastWorkout;

  bool get isEmpty => current.workouts == 0;
}
