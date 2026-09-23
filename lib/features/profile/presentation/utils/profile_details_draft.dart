import '../../domain/models/profile_details.dart';

/// Wybierane (jeszcze niezapisane) dane o sobie i cel. Wartości ustawiają
/// kontrolki z zakresami (linijka, koła daty), więc szkic jest zawsze
/// poprawny — `null` oznacza „nie podano”.
class ProfileDetailsDraft {
  const ProfileDetailsDraft({
    this.gender,
    this.birthDate,
    this.heightCm,
    this.weightKg,
    this.trainingGoal,
    this.experienceLevel,
    this.weeklyTrainingDays,
  });

  factory ProfileDetailsDraft.fromDetails(ProfileDetails? details) {
    final d = details ?? ProfileDetails.empty;
    return ProfileDetailsDraft(
      gender: d.gender,
      birthDate: d.birthDate,
      heightCm: d.heightCm,
      weightKg: d.weightKg,
      trainingGoal: d.trainingGoal,
      experienceLevel: d.experienceLevel,
      weeklyTrainingDays: d.weeklyTrainingDays,
    );
  }

  final Gender? gender;
  final DateTime? birthDate;
  final int? heightCm;
  final double? weightKg;
  final TrainingGoal? trainingGoal;
  final ExperienceLevel? experienceLevel;
  final int? weeklyTrainingDays;

  int? ageOn(DateTime today) {
    final birth = birthDate;
    return birth == null ? null : fullYearsBetween(birth, today);
  }

  /// [base] z polami z kroku „O Tobie” z tego szkicu.
  ProfileDetails bodyOnto(ProfileDetails base) => ProfileDetails(
    birthDate: birthDate,
    gender: gender,
    heightCm: heightCm,
    weightKg: weightKg,
    trainingGoal: base.trainingGoal,
    experienceLevel: base.experienceLevel,
    weeklyTrainingDays: base.weeklyTrainingDays,
  );

  /// [base] z polami z kroku „Twój cel” z tego szkicu.
  ProfileDetails goalOnto(ProfileDetails base) => ProfileDetails(
    birthDate: base.birthDate,
    gender: base.gender,
    heightCm: base.heightCm,
    weightKg: base.weightKg,
    trainingGoal: trainingGoal,
    experienceLevel: experienceLevel,
    weeklyTrainingDays: weeklyTrainingDays,
  );

  ProfileDetails toDetails() => goalOnto(bodyOnto(ProfileDetails.empty));

  /// Każde pole można wyczyścić — `clear*` ustawia null.
  ProfileDetailsDraft copyWith({
    Gender? gender,
    bool clearGender = false,
    DateTime? birthDate,
    bool clearBirthDate = false,
    int? heightCm,
    bool clearHeight = false,
    double? weightKg,
    bool clearWeight = false,
    TrainingGoal? trainingGoal,
    bool clearTrainingGoal = false,
    ExperienceLevel? experienceLevel,
    bool clearExperienceLevel = false,
    int? weeklyTrainingDays,
    bool clearWeeklyTrainingDays = false,
  }) {
    return ProfileDetailsDraft(
      gender: clearGender ? null : (gender ?? this.gender),
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      heightCm: clearHeight ? null : (heightCm ?? this.heightCm),
      weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
      trainingGoal: clearTrainingGoal
          ? null
          : (trainingGoal ?? this.trainingGoal),
      experienceLevel: clearExperienceLevel
          ? null
          : (experienceLevel ?? this.experienceLevel),
      weeklyTrainingDays: clearWeeklyTrainingDays
          ? null
          : (weeklyTrainingDays ?? this.weeklyTrainingDays),
    );
  }
}

/// Nick bez `@` i spacji na brzegach, małymi literami.
String normalizeHandle(String value) =>
    value.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');

String? handleInputError(String value) {
  final handle = normalizeHandle(value);
  if (handle.isEmpty) return 'Podaj nick.';
  if (handle.length < kHandleMinLength) {
    return 'Nick musi mieć co najmniej $kHandleMinLength znaki.';
  }
  if (handle.length > kHandleMaxLength) {
    return 'Nick może mieć maksymalnie $kHandleMaxLength znaków.';
  }
  if (handle.startsWith('.') || handle.startsWith('_')) {
    return 'Nick musi zaczynać się literą lub cyfrą.';
  }
  if (!kHandlePattern.hasMatch(handle)) {
    return 'Dozwolone: małe litery, cyfry, kropka i podkreślenie.';
  }
  return null;
}
