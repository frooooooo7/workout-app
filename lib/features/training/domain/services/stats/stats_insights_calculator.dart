import '../../../../../core/utils/polish_plural.dart';
import '../../models/training_stats.dart';
import '../../models/training_summary_stats.dart';

/// Krótkie wnioski z policzonych statystyk. Każda reguła daje najwyżej jeden
/// wniosek, a na ekran trafia [maxInsights] najpilniejszych.
abstract final class StatsInsightsCalculator {
  static const maxInsights = 4;

  /// Zmiana objętości, od której warto o niej wspomnieć. Spadek ma wyższy
  /// próg — tydzień z mniejszą liczbą serii to normalna zmienność, nie sygnał.
  static const volumeUpThreshold = 10;
  static const volumeDownThreshold = 15;

  /// Bez tylu treningów w oknie „stoi w miejscu” to przypadek, nie plateau.
  static const plateauMinSessions = 6;
  static const plateauSessionsSinceBest = 4;

  static const inactivityDays = 7;

  static List<StatsInsight> compute({
    required TrainingPeriodStats current,
    required TrainingPeriodStats? previous,
    required List<PersonalRecord> windowRecords,
    required int streakWeeks,
    required WeeklyGoalProgress? goal,
    required List<ExerciseProgress> exercises,
    required List<String> neglectedLabels,
    required int? daysSinceLastWorkout,
    required DateTime today,
  }) {
    final insights = <StatsInsight>[];

    final days = daysSinceLastWorkout;
    if (days != null && days >= inactivityDays) {
      insights.add(
        StatsInsight(
          kind: StatsInsightKind.inactivity,
          tone: StatsInsightTone.attention,
          text:
              'Ostatni trening był $days ${polishPlural(days, 'dzień', 'dni', 'dni')} '
              'temu. Wróć do rytmu.',
        ),
      );
    }

    if (goal != null) {
      final noun = polishPlural(
        goal.goal,
        'treningu',
        'treningów',
        'treningów',
      );
      if (goal.met) {
        insights.add(
          StatsInsight(
            kind: StatsInsightKind.goalMet,
            tone: StatsInsightTone.positive,
            text:
                'Cel tygodnia wykonany: ${goal.workoutsThisWeek} z ${goal.goal} $noun.',
          ),
        );
      } else if (today.weekday >= DateTime.thursday && goal.reachable) {
        final r = goal.remaining;
        insights.add(
          StatsInsight(
            kind: StatsInsightKind.goalBehind,
            tone: StatsInsightTone.neutral,
            text:
                'Do celu tygodnia brakuje $r '
                '${polishPlural(r, 'treningu', 'treningów', 'treningów')}.',
          ),
        );
      }
    }

    if (windowRecords.isNotEmpty) {
      final n = windowRecords.length;
      final latest = windowRecords.first;
      insights.add(
        StatsInsight(
          kind: StatsInsightKind.records,
          tone: StatsInsightTone.positive,
          text: n == 1
              ? 'Nowy rekord: ${latest.exerciseName}.'
              : '$n ${polishPlural(n, 'nowy rekord', 'nowe rekordy', 'nowych rekordów')}'
                    ' — ostatni: ${latest.exerciseName}.',
          exerciseId: latest.exerciseId,
        ),
      );
    }

    final prev = previous;
    if (prev != null && prev.workouts > 0 && current.workouts > 0) {
      if (prev.volumeKg > 0) {
        final change =
            ((current.volumeKg - prev.volumeKg) / prev.volumeKg * 100).round();
        if (change >= volumeUpThreshold) {
          insights.add(
            StatsInsight(
              kind: StatsInsightKind.volumeUp,
              tone: StatsInsightTone.positive,
              text: 'Objętość wzrosła o $change% względem poprzedniego okresu.',
            ),
          );
        } else if (change <= -volumeDownThreshold) {
          insights.add(
            StatsInsight(
              kind: StatsInsightKind.volumeDown,
              tone: StatsInsightTone.attention,
              text:
                  'Objętość spadła o ${-change}% względem poprzedniego okresu.',
            ),
          );
        }
      }
    }

    final plateau = _plateau(exercises);
    if (plateau != null) insights.add(plateau);

    final progress = _progress(exercises);
    if (progress != null) insights.add(progress);

    if (streakWeeks >= 3) {
      insights.add(
        StatsInsight(
          kind: StatsInsightKind.streak,
          tone: StatsInsightTone.positive,
          text:
              'Seria $streakWeeks '
              '${polishPlural(streakWeeks, 'tygodnia', 'tygodni', 'tygodni')} '
              'z rzędu z treningiem.',
        ),
      );
    }

    if (neglectedLabels.isNotEmpty) {
      final shown = neglectedLabels.take(3).join(', ');
      insights.add(
        StatsInsight(
          kind: StatsInsightKind.neglected,
          tone: StatsInsightTone.attention,
          text: 'Bez serii w tym okresie: $shown.',
        ),
      );
    }

    return List.unmodifiable(insights.take(maxInsights));
  }

  /// Wartość do porównań progresu: szacowane 1RM, a bez ciężarów powtórzenia.
  static List<double> _values(ExerciseProgress e) {
    if (e.hasWeights) {
      return [
        for (final p in e.points)
          if ((p.oneRepMaxKg ?? 0) > 0) p.oneRepMaxKg!,
      ];
    }
    return [
      for (final p in e.points)
        if (p.maxReps != null) p.maxReps!.toDouble(),
    ];
  }

  /// Ile treningów minęło od najlepszego wyniku, gdy ćwiczenie stoi w miejscu;
  /// `null`, gdy się rozwija albo za mało danych.
  static int? _stalledFor(ExerciseProgress e) {
    final values = _values(e);
    if (values.length < plateauMinSessions) return null;
    var best = 0;
    for (var i = 1; i < values.length; i++) {
      // Poprawa mniejsza niż ułamek procenta to szum zaokrągleń Epleya.
      if (values[i] > values[best] * 1.005) best = i;
    }
    final since = values.length - 1 - best;
    return since >= plateauSessionsSinceBest ? since : null;
  }

  static StatsInsight? _plateau(List<ExerciseProgress> exercises) {
    for (final e in exercises) {
      final since = _stalledFor(e);
      if (since == null) continue;
      return StatsInsight(
        kind: StatsInsightKind.plateau,
        tone: StatsInsightTone.attention,
        text:
            '${e.exerciseName}: bez progresu od $since '
            '${polishPlural(since, 'treningu', 'treningów', 'treningów')}.',
        exerciseId: e.exerciseId,
      );
    }
    return null;
  }

  static StatsInsight? _progress(List<ExerciseProgress> exercises) {
    ExerciseProgress? leader;
    var leaderChange = 0.0;
    for (final e in exercises) {
      if (_values(e).length < 3) continue;
      // Ćwiczenie w stagnacji nie może jednocześnie „rosnąć”: zmiana między
      // pierwszym a ostatnim punktem bywa dodatnia, choć od tygodni nic
      // się nie poprawiło.
      if (_stalledFor(e) != null) continue;
      final change = e.change;
      if (change != null && change > leaderChange) {
        leader = e;
        leaderChange = change;
      }
    }
    if (leader == null) return null;
    final text = leader.hasWeights
        ? '${leader.exerciseName}: szacowane 1RM wzrosło o '
              '${_decimal(leaderChange)} kg.'
        : '${leader.exerciseName}: rekord powtórzeń wzrósł o '
              '${leaderChange.round()}.';
    return StatsInsight(
      kind: StatsInsightKind.progress,
      tone: StatsInsightTone.positive,
      text: text,
      exerciseId: leader.exerciseId,
    );
  }

  static String _decimal(double value) {
    final rounded = (value * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? '${rounded.round()}'
        : rounded.toStringAsFixed(1).replaceAll('.', ',');
  }
}
