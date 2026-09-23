import '../../domain/models/profile_details.dart';
import 'profile_details_labels.dart';

/// Wpisywane (jeszcze niezapisane) dane o sobie i cel — surowy tekst pól
/// liczbowych i daty plus walidacja. Puste pole = „nie podano” (bez błędu).
class ProfileDetailsDraft {
  const ProfileDetailsDraft({
    this.gender,
    this.birthDateText = '',
    this.heightText = '',
    this.weightText = '',
    this.trainingGoal,
    this.experienceLevel,
    this.weeklyTrainingDays,
  });

  factory ProfileDetailsDraft.fromDetails(ProfileDetails? details) {
    final d = details ?? ProfileDetails.empty;
    return ProfileDetailsDraft(
      gender: d.gender,
      birthDateText: d.birthDate == null ? '' : formatBirthDate(d.birthDate!),
      heightText: d.heightCm?.toString() ?? '',
      weightText: d.weightKg == null ? '' : _weightInputText(d.weightKg!),
      trainingGoal: d.trainingGoal,
      experienceLevel: d.experienceLevel,
      weeklyTrainingDays: d.weeklyTrainingDays,
    );
  }

  final Gender? gender;

  /// `DD.MM.RRRR`
  final String birthDateText;
  final String heightText;
  final String weightText;
  final TrainingGoal? trainingGoal;
  final ExperienceLevel? experienceLevel;
  final int? weeklyTrainingDays;

  DateTime? get birthDate => parseBirthDateInput(birthDateText);

  int? get heightCm {
    final value = int.tryParse(heightText.trim());
    if (value == null || value < kMinHeightCm || value > kMaxHeightCm) {
      return null;
    }
    return value;
  }

  double? get weightKg {
    final value = double.tryParse(weightText.trim().replaceAll(',', '.'));
    if (value == null || value < kMinWeightKg || value > kMaxWeightKg) {
      return null;
    }
    return (value * 10).round() / 10;
  }

  String? get birthDateError =>
      birthDateInputError(birthDateText, DateTime.now());

  String? get heightError => heightText.trim().isEmpty || heightCm != null
      ? null
      : 'Podaj wzrost w cm ($kMinHeightCm–$kMaxHeightCm).';

  String? get weightError => weightText.trim().isEmpty || weightKg != null
      ? null
      : 'Podaj wagę w kg (${kMinWeightKg.toInt()}–${kMaxWeightKg.toInt()}).';

  bool get isBodyValid =>
      birthDateError == null && heightError == null && weightError == null;

  /// Wiek z poprawnie wpisanej daty.
  int? get age {
    final birth = birthDate;
    if (birth == null || birthDateError != null) return null;
    return fullYearsBetween(birth, DateTime.now());
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

  /// Wybory (płeć, cel, poziom, dni) można odznaczyć — `clear*` ustawia null.
  ProfileDetailsDraft copyWith({
    Gender? gender,
    bool clearGender = false,
    String? birthDateText,
    String? heightText,
    String? weightText,
    TrainingGoal? trainingGoal,
    bool clearTrainingGoal = false,
    ExperienceLevel? experienceLevel,
    bool clearExperienceLevel = false,
    int? weeklyTrainingDays,
    bool clearWeeklyTrainingDays = false,
  }) {
    return ProfileDetailsDraft(
      gender: clearGender ? null : (gender ?? this.gender),
      birthDateText: birthDateText ?? this.birthDateText,
      heightText: heightText ?? this.heightText,
      weightText: weightText ?? this.weightText,
      trainingGoal:
          clearTrainingGoal ? null : (trainingGoal ?? this.trainingGoal),
      experienceLevel: clearExperienceLevel
          ? null
          : (experienceLevel ?? this.experienceLevel),
      weeklyTrainingDays: clearWeeklyTrainingDays
          ? null
          : (weeklyTrainingDays ?? this.weeklyTrainingDays),
    );
  }

  static String _weightInputText(double kg) => kg == kg.roundToDouble()
      ? kg.toInt().toString()
      : kg.toStringAsFixed(1).replaceAll('.', ',');
}

/// `DD.MM.RRRR` → data; `null`, gdy niepełna albo nie istnieje.
DateTime? parseBirthDateInput(String text) {
  final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(text.trim());
  if (match == null) return null;
  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

/// Błąd daty urodzenia w dniu [today]; puste pole jest poprawne.
String? birthDateInputError(String text, DateTime today) {
  if (text.trim().isEmpty) return null;
  final date = parseBirthDateInput(text);
  if (date == null) return 'Podaj datę w formacie DD.MM.RRRR.';
  final age = fullYearsBetween(date, today);
  if (age < kMinUserAge) return 'Musisz mieć co najmniej $kMinUserAge lat.';
  if (age > kMaxUserAge) return 'Sprawdź rok urodzenia.';
  return null;
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
