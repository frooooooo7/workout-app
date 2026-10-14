import 'package:uuid/uuid.dart';

import '../../../../core/theme/plan_colors.dart';

import '../../../library/domain/models/exercise.dart';

class ExerciseSet {
  ExerciseSet({
    String? id,
    this.weight,
    this.reps = '',
    this.rir,
    this.tempo,
    this.durationSeconds,
    this.distanceM,
  }) : id = id ?? const Uuid().v4();

  final String id;
  final String? weight;
  final String reps;
  final String? rir;
  final String? tempo;

  /// Cel czasu i dystansu serii kardio (dystans zawsze w metrach).
  final int? durationSeconds;
  final int? distanceM;

  ExerciseSet copyWith({
    String? id,
    String? weight,
    String? reps,
    String? rir,
    String? tempo,
    int? durationSeconds,
    int? distanceM,
    bool clearWeight = false,
    bool clearRir = false,
    bool clearTempo = false,
    bool clearDuration = false,
    bool clearDistance = false,
  }) {
    return ExerciseSet(
      id: id ?? this.id,
      weight: clearWeight ? null : (weight ?? this.weight),
      reps: reps ?? this.reps,
      rir: clearRir ? null : (rir ?? this.rir),
      tempo: clearTempo ? null : (tempo ?? this.tempo),
      durationSeconds: clearDuration
          ? null
          : (durationSeconds ?? this.durationSeconds),
      distanceM: clearDistance ? null : (distanceM ?? this.distanceM),
    );
  }
}

class PlanExercise {
  PlanExercise({
    String? id,
    required this.exercise,
    List<ExerciseSet>? sets,
    this.isExpanded = false,
    this.restSeconds,
    this.supersetGroup,
  })  : id = id ?? const Uuid().v4(),
        sets = sets ?? [ExerciseSet()]; // Domyślnie jedna pusta seria

  final String id;
  final Exercise exercise;
  final List<ExerciseSet> sets;
  final bool isExpanded;

  /// Przerwa po serii; `null` = domyślna przerwa planu. W superserii
  /// liczy się przerwa ostatniego ćwiczenia grupy (po całej rundzie).
  final int? restSeconds;

  /// Litera superserii (A, B…) wspólna dla ćwiczeń jednej grupy.
  final String? supersetGroup;

  PlanExercise copyWith({
    String? id,
    Exercise? exercise,
    List<ExerciseSet>? sets,
    bool? isExpanded,
    int? restSeconds,
    String? supersetGroup,
    bool clearRestSeconds = false,
    bool clearSupersetGroup = false,
  }) {
    return PlanExercise(
      id: id ?? this.id,
      exercise: exercise ?? this.exercise,
      sets: sets ?? this.sets,
      isExpanded: isExpanded ?? this.isExpanded,
      restSeconds: clearRestSeconds ? null : (restSeconds ?? this.restSeconds),
      supersetGroup: clearSupersetGroup
          ? null
          : (supersetGroup ?? this.supersetGroup),
    );
  }
}

/// Cel planu — podpowiada powtórzenia i przerwę dla nowych ćwiczeń.
enum PlanGoal {
  strength('Siła', '3–5', 180),
  hypertrophy('Masa', '8–12', 90),
  endurance('Wytrzym.', '15+', 45);

  const PlanGoal(this.label, this.repRange, this.restSeconds);

  final String label;

  /// Zakres powtórzeń wpisywany do nowej serii.
  final String repRange;

  /// Domyślna przerwa planu po wyborze celu.
  final int restSeconds;

  /// Wartość w API (`strength`, `hypertrophy`, `endurance`).
  String get apiName => name;

  static PlanGoal? fromApi(String? value) {
    for (final goal in values) {
      if (goal.name == value) return goal;
    }
    return null;
  }
}

class CustomTrainingPlan {
  CustomTrainingPlan({
    String? id,
    required this.name,
    this.note,
    this.exercises = const [],
    this.selectedDays = const [],
    this.clientId,
    this.defaultRestSeconds = defaultRest,
    this.colorKey,
    this.iconKey,
    this.goal,
    this.progressionStepKg,
    this.highlightPlanColor = true,
    this.showRir = true,
    this.showTempo = true,
  }) : id = id ?? const Uuid().v4();

  /// Domyślna przerwa nowego planu (i planów sprzed tej funkcji).
  static const defaultRest = 120;

  final String id;
  final String name;
  final String? note;
  final List<PlanExercise> exercises;
  final List<int> selectedDays; // 1 = Poniedziałek, ..., 7 = Niedziela

  /// Lokalny identyfikator, pod którym plan został utworzony offline. Serwer
  /// odsyła go przy pobieraniu — dzięki temu synchronizacja paruje plan
  /// z wierszem lokalnym nawet po zgubionej odpowiedzi na `POST`.
  final String? clientId;

  /// Przerwa ćwiczeń bez własnej ([PlanExercise.restSeconds] == `null`).
  final int defaultRestSeconds;

  /// Kolor z [PlanColors.palette] po kluczu; `null` = dobierany z nazwy.
  final String? colorKey;

  /// Ikona z [PlanIcons]; `null` = pierwsza litera nazwy.
  final String? iconKey;

  final PlanGoal? goal;

  /// Krok podpowiedzi progresji (`+2,5`); `null` = domyślny krok aplikacji.
  final double? progressionStepKg;

  /// Aktywna seria, check i przerwa w kolorze planu zamiast niebieskiego.
  final bool highlightPlanColor;

  /// Kolumny RIR i tempo na ekranie treningu.
  final bool showRir;
  final bool showTempo;

  /// Wygląd i ustawienia treningu dla ekranów znających tylko nazwę planu.
  PlanStyle get style => PlanStyle(
    colorKey: colorKey,
    iconKey: iconKey,
    highlightPlanColor: highlightPlanColor,
    showRir: showRir,
    showTempo: showTempo,
    progressionStepKg: progressionStepKg,
  );

  /// Przerwa po serii [exercise]: własna albo domyślna planu.
  int restFor(PlanExercise exercise) =>
      exercise.restSeconds ?? defaultRestSeconds;

  CustomTrainingPlan copyWith({
    String? id,
    String? name,
    String? note,
    List<PlanExercise>? exercises,
    List<int>? selectedDays,
    String? clientId,
    bool clearNote = false,
    int? defaultRestSeconds,
    String? colorKey,
    String? iconKey,
    PlanGoal? goal,
    double? progressionStepKg,
    bool? highlightPlanColor,
    bool? showRir,
    bool? showTempo,
    bool clearColorKey = false,
    bool clearIconKey = false,
    bool clearGoal = false,
    bool clearProgressionStep = false,
  }) {
    return CustomTrainingPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      note: clearNote ? null : (note ?? this.note),
      exercises: exercises ?? this.exercises,
      selectedDays: selectedDays ?? this.selectedDays,
      clientId: clientId ?? this.clientId,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
      colorKey: clearColorKey ? null : (colorKey ?? this.colorKey),
      iconKey: clearIconKey ? null : (iconKey ?? this.iconKey),
      goal: clearGoal ? null : (goal ?? this.goal),
      progressionStepKg: clearProgressionStep
          ? null
          : (progressionStepKg ?? this.progressionStepKg),
      highlightPlanColor: highlightPlanColor ?? this.highlightPlanColor,
      showRir: showRir ?? this.showRir,
      showTempo: showTempo ?? this.showTempo,
    );
  }
}
