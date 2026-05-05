/// Mock plan dla widoku „Trening” (offline / placeholder).
class TrainingDayPlan {
  const TrainingDayPlan({
    required this.weekday,
    required this.progressStep,
    required this.name,
    required this.type,
    required this.dayLabel,
    required this.exerciseCount,
    required this.durationMin,
    required this.muscles,
  });

  /// `DateTime.weekday` — 1 = poniedziałek … 7 = niedziela.
  final int weekday;

  /// Pozycja w cyklu 3-dniowym — używana jako `value` paska postępu (÷ 3).
  final int progressStep;

  final String name;
  final String type;
  final String dayLabel;
  final int exerciseCount;
  final int durationMin;
  final String muscles;

  double get progress01 => progressStep / 3.0;
}

/// Klucze: dni treningowe w tygodniu (`DateTime.weekday`).
const Map<int, TrainingDayPlan> kTrainingPlansByWeekday = {
  1: TrainingDayPlan(
    weekday: 1,
    progressStep: 1,
    name: 'Push Day',
    type: 'Push',
    dayLabel: 'Dzień 1 z 3',
    exerciseCount: 6,
    durationMin: 70,
    muscles: 'Klatka, barki, triceps',
  ),
  3: TrainingDayPlan(
    weekday: 3,
    progressStep: 2,
    name: 'Pull Day',
    type: 'Pull',
    dayLabel: 'Dzień 2 z 3',
    exerciseCount: 5,
    durationMin: 60,
    muscles: 'Plecy, biceps',
  ),
  5: TrainingDayPlan(
    weekday: 5,
    progressStep: 3,
    name: 'Leg Day',
    type: 'Nogi',
    dayLabel: 'Dzień 3 z 3',
    exerciseCount: 7,
    durationMin: 80,
    muscles: 'Nogi, pośladki',
  ),
};

/// Dni tygodnia z zaplanowanym treningiem (mock UI).
const Set<int> kTrainingWorkoutWeekdays = {1, 3, 5};

const List<String> kTrainingWeekdayShortLabels = [
  'Pon',
  'Wt',
  'Śr',
  'Czw',
  'Pt',
  'Sob',
  'Ndz',
];
