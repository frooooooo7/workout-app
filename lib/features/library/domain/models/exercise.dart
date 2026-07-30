// ──────────────────────────────────────────────
// Enums
// ──────────────────────────────────────────────

/// Partia ciała grupująca [MuscleGroup] — używana do filtrów i sekcji
/// w pickerze mięśni, żeby granularna lista nie wysypała się jako płaski ciąg.
enum MuscleRegion {
  chest,
  back,
  shoulders,
  arms,
  core,
  legs;

  String get label => switch (this) {
        MuscleRegion.chest => 'Klatka',
        MuscleRegion.back => 'Plecy',
        MuscleRegion.shoulders => 'Barki',
        MuscleRegion.arms => 'Ramiona',
        MuscleRegion.core => 'Core',
        MuscleRegion.legs => 'Nogi',
      };
}

/// Grupy mięśniowe ćwiczenia.
///
/// Wartości [chest], [back], [legs], [shoulders], [biceps], [triceps], [abs]
/// i [glutes] istnieją w bazie od pierwszego seeda i **nie wolno ich usuwać** —
/// rozparsowanie zapisanych ćwiczeń i snapshotów sesji od nich zależy.
/// Trzy z nich ([back], [legs], [shoulders]) są zbiorcze: na manekinie zapalają
/// cały swój region przez [expanded], bo nie niosą informacji o konkretnym
/// mięśniu. Nowe ćwiczenia warto tagować wartościami granularnymi.
enum MuscleGroup {
  all,

  // ── Istniejące w bazie (nie usuwać) ───────────
  chest,
  back,
  legs,
  shoulders,
  biceps,
  triceps,
  abs,
  glutes,

  // ── Granularne ────────────────────────────────
  traps,
  lats,
  rhomboids,
  lowerBack,
  frontDelts,
  sideDelts,
  rearDelts,
  forearms,
  obliques,
  quads,
  hamstrings,
  calves,
  adductors;

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
        MuscleGroup.traps => 'Kaptury',
        MuscleGroup.lats => 'Najszersze grzbietu',
        MuscleGroup.rhomboids => 'Romboidalne',
        MuscleGroup.lowerBack => 'Prostowniki grzbietu',
        MuscleGroup.frontDelts => 'Przednie naramienne',
        MuscleGroup.sideDelts => 'Boczne naramienne',
        MuscleGroup.rearDelts => 'Tylne naramienne',
        MuscleGroup.forearms => 'Przedramiona',
        MuscleGroup.obliques => 'Skośne brzucha',
        MuscleGroup.quads => 'Czworogłowe uda',
        MuscleGroup.hamstrings => 'Dwugłowe uda',
        MuscleGroup.calves => 'Łydki',
        MuscleGroup.adductors => 'Przywodziciele',
      };

  /// Skrócona etykieta pod wąskie miejsca (paski na mapie mięśni, chipy).
  String get shortLabel => switch (this) {
        MuscleGroup.chest => 'Klatka',
        MuscleGroup.lats => 'Najszersze',
        MuscleGroup.lowerBack => 'Prostowniki',
        MuscleGroup.frontDelts => 'Przednie barki',
        MuscleGroup.sideDelts => 'Boczne barki',
        MuscleGroup.rearDelts => 'Tylne barki',
        MuscleGroup.obliques => 'Skośne',
        MuscleGroup.quads => 'Czworogłowe',
        MuscleGroup.hamstrings => 'Dwugłowe',
        _ => label,
      };

  /// Partia ciała, do której należy grupa. `null` tylko dla [all] (sentinel
  /// filtra, nie jest realną grupą mięśniową).
  MuscleRegion? get region => switch (this) {
        MuscleGroup.all => null,
        MuscleGroup.chest => MuscleRegion.chest,
        MuscleGroup.back ||
        MuscleGroup.traps ||
        MuscleGroup.lats ||
        MuscleGroup.rhomboids ||
        MuscleGroup.lowerBack =>
          MuscleRegion.back,
        MuscleGroup.shoulders ||
        MuscleGroup.frontDelts ||
        MuscleGroup.sideDelts ||
        MuscleGroup.rearDelts =>
          MuscleRegion.shoulders,
        MuscleGroup.biceps || MuscleGroup.triceps || MuscleGroup.forearms =>
          MuscleRegion.arms,
        MuscleGroup.abs || MuscleGroup.obliques => MuscleRegion.core,
        MuscleGroup.legs ||
        MuscleGroup.glutes ||
        MuscleGroup.quads ||
        MuscleGroup.hamstrings ||
        MuscleGroup.calves ||
        MuscleGroup.adductors =>
          MuscleRegion.legs,
      };

  /// Grupa zbiorcza — nie wskazuje pojedynczego mięśnia, więc na manekinie
  /// rozkłada się na wszystkie mięśnie swojego regionu.
  bool get isCoarse =>
      this == MuscleGroup.back ||
      this == MuscleGroup.legs ||
      this == MuscleGroup.shoulders;

  /// Konkretne mięśnie, które ta grupa zapala na manekinie.
  Set<MuscleGroup> get expanded => switch (this) {
        MuscleGroup.all => const {},
        MuscleGroup.back => const {
            MuscleGroup.traps,
            MuscleGroup.lats,
            MuscleGroup.rhomboids,
            MuscleGroup.lowerBack,
          },
        MuscleGroup.legs => const {
            MuscleGroup.quads,
            MuscleGroup.hamstrings,
            MuscleGroup.calves,
            MuscleGroup.adductors,
          },
        MuscleGroup.shoulders => const {
            MuscleGroup.frontDelts,
            MuscleGroup.sideDelts,
            MuscleGroup.rearDelts,
          },
        _ => {this},
      };

  /// Parsuje nazwę enuma zapisaną w API/bazie. Zwraca `null` dla nieznanych
  /// wartości, żeby starszy klient nie wywracał się na nowej grupie z serwera.
  static MuscleGroup? tryParse(String? raw) {
    if (raw == null) return null;
    for (final value in MuscleGroup.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
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
