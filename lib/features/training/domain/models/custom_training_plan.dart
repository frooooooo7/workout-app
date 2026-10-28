import 'package:uuid/uuid.dart';

import '../../../../core/theme/plan_colors.dart';

import '../../../library/domain/models/exercise.dart';
import 'progression_settings.dart';

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
    this.progression,
    this.highlightPlanColor = true,
    this.showRir = true,
    this.showTempo = true,
    this.isPublic = false,
    this.copiedFrom,
    this.copyCount = 0,
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

  /// Krok progresji z wersji sprzed Ustawień → Progresja (w kg). Plan, który
  /// go ma, a nie ma [progression], liczy się jako „Stały krok” z tym krokiem.
  final double? progressionStepKg;

  /// Własna metoda progresji planu; `null` = jak w ustawieniach konta.
  final ProgressionSettings? progression;

  /// Metoda planu (własna albo przeniesiona ze starego kroku); `null` = jak
  /// w ustawieniach konta.
  ProgressionSettings? get planProgression =>
      progression ??
      (progressionStepKg == null
          ? null
          : ProgressionSettings.legacyStep(progressionStepKg!));

  /// Aktywna seria, check i przerwa w kolorze planu zamiast niebieskiego.
  final bool highlightPlanColor;

  /// Kolumny RIR i tempo na ekranie treningu.
  final bool showRir;
  final bool showTempo;

  /// Plan widoczny na profilu — inni mogą go podejrzeć i skopiować.
  final bool isPublic;

  /// Autor planu, z którego zrobiono tę kopię; `null` — plan własny.
  final PlanAuthor? copiedFrom;

  /// Ile razy inni skopiowali ten plan.
  final int copyCount;

  /// Wygląd i ustawienia treningu dla ekranów znających tylko nazwę planu.
  PlanStyle get style => PlanStyle(
    colorKey: colorKey,
    iconKey: iconKey,
    highlightPlanColor: highlightPlanColor,
    showRir: showRir,
    showTempo: showTempo,
    progression: planProgression,
  );

  /// Przerwa po serii [exercise]: własna albo domyślna planu.
  int restFor(PlanExercise exercise) =>
      exercise.restSeconds ?? defaultRestSeconds;

  /// Szacunek czasu treningu: ~45 s na serię (odcinek kardio — jego czas)
  /// i przerwa po każdej serii, a w superserii po każdej rundzie.
  /// Zaokrąglony do 5 minut, co najmniej 5.
  int get estimatedMinutes {
    var seconds = 0;
    for (var i = 0; i < exercises.length; i++) {
      final exercise = exercises[i];
      for (final set in exercise.sets) {
        seconds += set.durationSeconds ?? 45;
      }
      final group = exercise.supersetGroup;
      if (group != null &&
          i + 1 < exercises.length &&
          exercises[i + 1].supersetGroup == group) {
        continue;
      }
      var rounds = exercise.sets.length;
      if (group != null) {
        for (final other in exercises) {
          if (other.supersetGroup == group && other.sets.length > rounds) {
            rounds = other.sets.length;
          }
        }
      }
      seconds += rounds * restFor(exercise);
    }
    final minutes = (seconds / 60 / 5).round() * 5;
    return minutes < 5 ? 5 : minutes;
  }

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
    ProgressionSettings? progression,
    bool? highlightPlanColor,
    bool? showRir,
    bool? showTempo,
    bool? isPublic,
    int? copyCount,
    bool clearColorKey = false,
    bool clearIconKey = false,
    bool clearGoal = false,
    bool clearProgressionStep = false,
    bool clearProgression = false,
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
      progression: clearProgression ? null : (progression ?? this.progression),
      highlightPlanColor: highlightPlanColor ?? this.highlightPlanColor,
      showRir: showRir ?? this.showRir,
      showTempo: showTempo ?? this.showTempo,
      isPublic: isPublic ?? this.isPublic,
      copiedFrom: copiedFrom,
      copyCount: copyCount ?? this.copyCount,
    );
  }
}

/// Autor planu, z którego zrobiono kopię (`od @anna`).
class PlanAuthor {
  const PlanAuthor({required this.userId, this.handle});

  final String userId;

  /// `null`, gdy serwer nie zna już tej osoby (konto usunięte).
  final String? handle;

  @override
  bool operator ==(Object other) =>
      other is PlanAuthor && other.userId == userId && other.handle == handle;

  @override
  int get hashCode => Object.hash(userId, handle);
}
