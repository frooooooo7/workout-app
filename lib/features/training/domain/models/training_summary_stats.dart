enum ActivitySummaryPeriod { week, month }

/// Zagregowane wyniki treningów w jednym okresie (liczone lokalnie).
class TrainingPeriodStats {
  const TrainingPeriodStats({
    this.workouts = 0,
    this.durationSec = 0,
    this.completedSets = 0,
    this.reps = 0,
    this.volumeKg = 0,
    this.distinctExercises = 0,
  });

  final int workouts;
  final int durationSec;
  final int completedSets;
  final int reps;
  final double volumeKg;
  final int distinctExercises;

  static const empty = TrainingPeriodStats();

  @override
  bool operator ==(Object other) =>
      other is TrainingPeriodStats &&
      other.workouts == workouts &&
      other.durationSec == durationSec &&
      other.completedSets == completedSets &&
      other.reps == reps &&
      other.volumeKg == volumeKg &&
      other.distinctExercises == distinctExercises;

  @override
  int get hashCode => Object.hash(
    workouts,
    durationSec,
    completedSets,
    reps,
    volumeKg,
    distinctExercises,
  );

  @override
  String toString() =>
      'TrainingPeriodStats(workouts: $workouts, durationSec: $durationSec, '
      'sets: $completedSets, reps: $reps, volumeKg: $volumeKg, '
      'exercises: $distinctExercises)';
}

/// Bieżący tydzień (od poniedziałku 00:00) i bieżący miesiąc kalendarzowy.
class TrainingSummary {
  const TrainingSummary({required this.week, required this.month});

  final TrainingPeriodStats week;
  final TrainingPeriodStats month;

  static const empty = TrainingSummary(
    week: TrainingPeriodStats.empty,
    month: TrainingPeriodStats.empty,
  );

  TrainingPeriodStats of(ActivitySummaryPeriod period) =>
      period == ActivitySummaryPeriod.week ? week : month;
}

/// `18 960` — separator tysięcy dla dużych liczb w kafelkach.
String formatTrainingVolumeKg(int kg) {
  final digits = kg.abs().toString();
  final buffer = StringBuffer(kg < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
