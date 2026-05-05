// ──────────────────────────────────────────────
// Enums
// ──────────────────────────────────────────────

enum MuscleGroup {
  all,
  chest,
  back,
  legs,
  shoulders,
  biceps,
  triceps,
  abs,
  glutes;

  String get label => switch (this) {
        MuscleGroup.all => 'Wszystkie',
        MuscleGroup.chest => 'Klatka piersiowa',
        MuscleGroup.back => 'Plecy',
        MuscleGroup.legs => 'Nogi',
        MuscleGroup.shoulders => 'Barki',
        MuscleGroup.biceps => 'Biceps',
        MuscleGroup.triceps => 'Triceps',
        MuscleGroup.abs => 'Brzuch',
        MuscleGroup.glutes => 'Pośladki',
      };
}

enum ExerciseDifficulty {
  easy,
  medium,
  hard;

  String get label => switch (this) {
        ExerciseDifficulty.easy => 'Łatwe',
        ExerciseDifficulty.medium => 'Średnie',
        ExerciseDifficulty.hard => 'Trudne',
      };
}

enum ExerciseCategory {
  compound,
  isolation,
  cardio,
  mobility,
  plyometric,
  calisthenics;

  String get label => switch (this) {
        ExerciseCategory.compound => 'Wielostaw',
        ExerciseCategory.isolation => 'Izolowane',
        ExerciseCategory.cardio => 'Kardio',
        ExerciseCategory.mobility => 'Mobilność',
        ExerciseCategory.plyometric => 'Plyometria',
        ExerciseCategory.calisthenics => 'Kalistenika',
      };
}

enum LibraryFilter { all, mine, favourite, recent }

// ──────────────────────────────────────────────
// Model
// ──────────────────────────────────────────────

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.muscles,
    required this.category,
    this.description = '',
    this.imageUrl,
    this.isFavourite = false,
    this.isMine = false,
    this.createdAt,
    this.isPendingSync = false,
  });

  final String id;
  final String name;
  final List<MuscleGroup> muscles;
  final ExerciseCategory category;
  /// Optional user-visible instructions / notes from API (`description`).
  final String description;
  /// Relative upload path or absolute URL from API (`imageUrl`).
  final String? imageUrl;
  final bool isFavourite;
  final bool isMine;
  /// UTC timestamp from the server. Null for locally-constructed mock data.
  final DateTime? createdAt;
  /// Local row has outbound sync work (`pending_op` or dirty favourite).
  final bool isPendingSync;
}

// ──────────────────────────────────────────────
// Mock data
// ──────────────────────────────────────────────

const mockExercises = <Exercise>[
  Exercise(
    id: '1',
    name: 'Wyciskanie sztangi na ławce',
    muscles: [MuscleGroup.chest, MuscleGroup.triceps],
    category: ExerciseCategory.compound,
    isFavourite: true,
  ),
  Exercise(
    id: '2',
    name: 'Podciąganie na drążku',
    muscles: [MuscleGroup.back, MuscleGroup.biceps],
    category: ExerciseCategory.compound,
  ),
  Exercise(
    id: '3',
    name: 'Przysiad ze sztangą',
    muscles: [MuscleGroup.legs, MuscleGroup.glutes],
    category: ExerciseCategory.compound,
    isFavourite: true,
  ),
  Exercise(
    id: '4',
    name: 'Wyciskanie hantli nad głowę',
    muscles: [MuscleGroup.shoulders, MuscleGroup.triceps],
    category: ExerciseCategory.compound,
  ),
  Exercise(
    id: '5',
    name: 'Martwy ciąg',
    muscles: [MuscleGroup.back, MuscleGroup.legs],
    category: ExerciseCategory.compound,
  ),
  Exercise(
    id: '6',
    name: 'Uginanie ramion z hantlami',
    muscles: [MuscleGroup.biceps],
    category: ExerciseCategory.isolation,
    isMine: true,
  ),
  Exercise(
    id: '7',
    name: 'Pompki na poręczach',
    muscles: [MuscleGroup.chest, MuscleGroup.triceps, MuscleGroup.shoulders],
    category: ExerciseCategory.calisthenics,
  ),
  Exercise(
    id: '8',
    name: 'Wiosłowanie sztangą',
    muscles: [MuscleGroup.back, MuscleGroup.biceps],
    category: ExerciseCategory.compound,
  ),
  Exercise(
    id: '9',
    name: 'Wypychanie nóg na suwnicy',
    muscles: [MuscleGroup.legs, MuscleGroup.glutes],
    category: ExerciseCategory.isolation,
    isMine: true,
  ),
  Exercise(
    id: '10',
    name: 'Unoszenie ramion bokiem',
    muscles: [MuscleGroup.shoulders],
    category: ExerciseCategory.isolation,
  ),
  Exercise(
    id: '11',
    name: 'Prostowanie ramion na wyciągu',
    muscles: [MuscleGroup.triceps],
    category: ExerciseCategory.isolation,
    isFavourite: true,
  ),
  Exercise(
    id: '12',
    name: 'Plank',
    muscles: [MuscleGroup.abs],
    category: ExerciseCategory.calisthenics,
  ),
  Exercise(
    id: '13',
    name: 'Burpees',
    muscles: [MuscleGroup.legs, MuscleGroup.chest, MuscleGroup.abs],
    category: ExerciseCategory.plyometric,
  ),
  Exercise(
    id: '14',
    name: 'Rozciąganie łańcucha tylnego',
    muscles: [MuscleGroup.legs, MuscleGroup.back],
    category: ExerciseCategory.mobility,
  ),
];
