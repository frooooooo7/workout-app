enum ActivitySummaryPeriod {
  week,
  month,
}

/// Mocked aggregates for the summary view until backend statistics are wired.
class TrainingSummaryStats {
  const TrainingSummaryStats({
    required this.workouts,
    required this.durationH,
    required this.durationMin,
    required this.sets,
    required this.reps,
    required this.volumeKg,
    required this.distanceKm,
    required this.caloriesKcal,
  });

  final int workouts;
  final int durationH;
  final int durationMin;
  final int sets;
  final int reps;
  final int volumeKg;
  final double distanceKm;
  final int caloriesKcal;
}

const TrainingSummaryStats kTrainingSummaryWeek = TrainingSummaryStats(
  workouts: 3,
  durationH: 3,
  durationMin: 40,
  sets: 48,
  reps: 386,
  volumeKg: 4720,
  distanceKm: 12.4,
  caloriesKcal: 1840,
);

const TrainingSummaryStats kTrainingSummaryMonth = TrainingSummaryStats(
  workouts: 12,
  durationH: 14,
  durationMin: 55,
  sets: 192,
  reps: 1544,
  volumeKg: 18960,
  distanceKm: 47.2,
  caloriesKcal: 7360,
);

String formatTrainingVolumeKg(int kg) {
  if (kg >= 1000) {
    final thousands = kg ~/ 1000;
    final remainder = (kg % 1000).toString().padLeft(3, '0');
    return '$thousands $remainder';
  }
  return '$kg';
}

String workoutCountLabelPlural(int workouts) {
  if (workouts == 1) return 'trening';
  if (workouts <= 4) return 'treningi';
  return 'treningow';
}
