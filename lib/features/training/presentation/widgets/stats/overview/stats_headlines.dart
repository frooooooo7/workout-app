import '../../../../../../core/utils/polish_plural.dart';
import '../../../../../library/domain/models/exercise.dart';
import '../../../../domain/models/training_stats.dart';
import '../stats_format.dart';

/// Zdania i liczby kart pulpitu. Karta odpowiada na jedno pytanie, więc jej
/// nagłówkiem jest wniosek („Rośniesz w 6 z 8 ćwiczeń”), a nie nazwa danych.

/// Jak zmieniło się ćwiczenie od początku wykresu progresu: kg szacowanego
/// 1RM, a bez ciężaru powtórzenia.
class StatsExerciseTrend {
  const StatsExerciseTrend._({
    required this.exercise,
    required this.values,
    required this.change,
    required this.reps,
  });

  factory StatsExerciseTrend.of(ExerciseProgress exercise) {
    final weights = [
      for (final p in exercise.points)
        if ((p.oneRepMaxKg ?? 0) > 0) p.oneRepMaxKg!,
    ];
    if (weights.length >= 2 || exercise.hasWeights) {
      return StatsExerciseTrend._(
        exercise: exercise,
        values: weights,
        change: exercise.change,
        reps: false,
      );
    }
    final reps = [
      for (final p in exercise.points)
        if (p.maxReps != null) p.maxReps!.toDouble(),
    ];
    return StatsExerciseTrend._(
      exercise: exercise,
      values: reps,
      change: exercise.change,
      reps: true,
    );
  }

  final ExerciseProgress exercise;

  /// Punkty do mini-wykresu, od najstarszego.
  final List<double> values;

  /// Zmiana w jednostce [values] (kg albo powtórzenia); `null` bez dwóch
  /// punktów.
  final double? change;
  final bool reps;

  /// 1 wzrost, -1 spadek, 0 bez zmian, `null` — za mało danych.
  int? get direction {
    final c = change;
    if (c == null) return null;
    final eps = reps ? 0.5 : 0.05;
    if (c > eps) return 1;
    if (c < -eps) return -1;
    return 0;
  }

  /// „szac. 1RM 172 kg” / „max 15 powt.”; pusty bez punktów.
  String get currentLabel {
    if (values.isEmpty) return '';
    if (reps) return 'max ${values.last.round()} powt.';
    return 'szac. 1RM ${formatStatsWeight(values.last, digits: 0)}';
  }

  /// „10 kg” / „3 powt.” — bez znaku, kierunek niesie strzałka.
  String? get changeLabel {
    final c = change;
    if (c == null) return null;
    if (reps) return '${c.abs().round()} powt.';
    return formatStatsWeight(c.abs());
  }
}

abstract final class StatsHeadlines {
  /// Ile ćwiczeń zalicza się do „głównych” w zdaniu o sile.
  static const mainExercises = 8;

  /// Najczęściej robione ćwiczenia, dla których da się policzyć zmianę.
  static List<StatsExerciseTrend> strengthTrends(
    List<ExerciseProgress> exercises,
  ) => [
    for (final e in exercises.take(mainExercises)) StatsExerciseTrend.of(e),
  ];

  /// „Rośniesz w 6 z 8 głównych ćwiczeń”; `null`, gdy żadnego nie da się
  /// porównać.
  static String? strength(List<StatsExerciseTrend> trends) {
    final known = [
      for (final t in trends)
        if (t.direction != null) t,
    ];
    if (known.isEmpty) return null;
    final up = known.where((t) => t.direction == 1).length;
    final total = known.length;
    if (up == 0) return 'Bez wzrostu w głównych ćwiczeniach';
    if (total == 1) {
      return 'Rośniesz w ćwiczeniu ${known.first.exercise.exerciseName}';
    }
    if (up == total) {
      return 'Rośniesz we wszystkich $total głównych ćwiczeniach';
    }
    return 'Rośniesz w $up z $total głównych ćwiczeń';
  }

  /// „9 nowych rekordów”.
  static String records(int count) {
    if (count == 0) return 'Brak nowych rekordów';
    final noun = polishPlural(
      count,
      'nowy rekord',
      'nowe rekordy',
      'nowych rekordów',
    );
    return '$count $noun';
  }

  static String _muscleLabel(MuscleGroup g) =>
      g.isCoarse ? g.label : g.shortLabel;

  /// Zdanie nad mapą mięśni: pominięta partia ma pierwszeństwo, bo to jedyna
  /// rzecz, na którą użytkownik może zareagować.
  static String muscles(
    MuscleDistribution m,
    List<MuscleRecoveryStat> recovery,
  ) {
    final neglected = m.neglected;
    if (neglected.length == 1) {
      final label = _muscleLabel(neglected.first);
      final since = recovery
          .where((r) => r.muscle == neglected.first)
          .map((r) => r.daysSince)
          .firstOrNull;
      if (since != null && since >= 14) {
        final weeks = since ~/ 7;
        return '$label bez ani jednej serii od $weeks tygodni';
      }
      return '$label bez ani jednej serii w tym okresie';
    }
    if (neglected.length == 2) {
      return '${_muscleLabel(neglected[0])} i ${_muscleLabel(neglected[1])} '
          'bez ani jednej serii';
    }
    if (neglected.length > 2) {
      return '${neglected.length} mięśni bez ani jednej serii';
    }
    if (m.regions.isNotEmpty) {
      final top = m.regions.first;
      return 'Najwięcej serii: ${top.region.label} '
          '· ${(top.share * 100).round()}%';
    }
    return 'Rozkład pracy mięśni';
  }

  /// „Średnio 3,8 treningu w tygodniu”; `null` bez średniej.
  static String? perWeek(double? workoutsPerWeek) {
    if (workoutsPerWeek == null || workoutsPerWeek <= 0) return null;
    final rounded = double.parse(workoutsPerWeek.toStringAsFixed(1));
    final value = formatStatsDecimal(rounded);
    final noun = rounded == rounded.roundToDouble()
        ? polishPlural(rounded.round(), 'trening', 'treningi', 'treningów')
        : 'treningu';
    return 'Średnio $value $noun w tygodniu';
  }

  /// „Najczęściej w poniedziałki, wieczorem”; `null` bez treningów.
  static String? favorite(TrainingHabits h) {
    final day = h.favoriteWeekday;
    final time = h.favoriteTimeOfDay;
    if (day == null && time == null) return null;
    final parts = [
      if (day != null) _weekdayIn[day - 1],
      if (time != null) _timeIn(time),
    ];
    return 'Najczęściej ${parts.join(', ')}';
  }

  static const _weekdayIn = [
    'w poniedziałki',
    'we wtorki',
    'w środy',
    'w czwartki',
    'w piątki',
    'w soboty',
    'w niedziele',
  ];

  static String _timeIn(TrainingTimeOfDay t) => switch (t) {
    TrainingTimeOfDay.morning => 'rano',
    TrainingTimeOfDay.midday => 'w ciągu dnia',
    TrainingTimeOfDay.evening => 'wieczorem',
    TrainingTimeOfDay.night => 'nocą',
  };

  /// „5 tyg.” — pigułka passy.
  static String streak(int weeks) => '$weeks tyg.';

  /// Podpis zakresu nad liczbą treningów: „Ostatnie 30 dni”.
  static String periodTitle(TrainingStatsSnapshot s) => switch (s.range) {
    StatsRange.week => 'Ostatnie 7 dni',
    StatsRange.month => 'Ostatnie 30 dni',
    StatsRange.quarter => 'Ostatnie 3 miesiące',
    StatsRange.year => 'Ostatni rok',
    StatsRange.all => 'Cała historia',
    StatsRange.custom =>
      s.customRange == null
          ? 'Własny zakres'
          : '${formatStatsDayMonth(s.customRange!.start)} – '
                '${formatStatsDayMonth(s.customRange!.end)}',
  };
}
