/// Prywatne dane o sobie i cel treningowy — widzi je tylko właściciel
/// konta (`/profile/me*`). Każde pole może być puste („nie podano”).
class ProfileDetails {
  const ProfileDetails({
    this.birthDate,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.trainingGoal,
    this.experienceLevel,
    this.weeklyTrainingDays,
  });

  static const empty = ProfileDetails();

  /// Sama data (bez strefy czasowej) — lokalna północ.
  final DateTime? birthDate;
  final Gender? gender;
  final int? heightCm;
  final double? weightKg;
  final TrainingGoal? trainingGoal;
  final ExperienceLevel? experienceLevel;
  final int? weeklyTrainingDays;

  bool get isEmpty =>
      birthDate == null &&
      gender == null &&
      heightCm == null &&
      weightKg == null &&
      trainingGoal == null &&
      experienceLevel == null &&
      weeklyTrainingDays == null;

  /// Pełne lata w dniu [today].
  int? ageOn(DateTime today) {
    final birth = birthDate;
    if (birth == null) return null;
    return fullYearsBetween(birth, today);
  }

  factory ProfileDetails.fromJson(Map<String, dynamic> json) {
    return ProfileDetails(
      birthDate: parseIsoDate(json['birthDate'] as String?),
      gender: Gender.fromApi(json['gender'] as String?),
      heightCm: (json['heightCm'] as num?)?.toInt(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      trainingGoal: TrainingGoal.fromApi(json['trainingGoal'] as String?),
      experienceLevel: ExperienceLevel.fromApi(
        json['experienceLevel'] as String?,
      ),
      weeklyTrainingDays: (json['weeklyTrainingDays'] as num?)?.toInt(),
    );
  }

  /// Wszystkie pola — `null` czyści wartość na serwerze.
  Map<String, dynamic> toJson() => {
        'birthDate': birthDate == null ? null : formatIsoDate(birthDate!),
        'gender': gender?.apiValue,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'trainingGoal': trainingGoal?.apiValue,
        'experienceLevel': experienceLevel?.apiValue,
        'weeklyTrainingDays': weeklyTrainingDays,
      };

  @override
  bool operator ==(Object other) =>
      other is ProfileDetails &&
      other.birthDate == birthDate &&
      other.gender == gender &&
      other.heightCm == heightCm &&
      other.weightKg == weightKg &&
      other.trainingGoal == trainingGoal &&
      other.experienceLevel == experienceLevel &&
      other.weeklyTrainingDays == weeklyTrainingDays;

  @override
  int get hashCode => Object.hash(
        birthDate,
        gender,
        heightCm,
        weightKg,
        trainingGoal,
        experienceLevel,
        weeklyTrainingDays,
      );
}

enum Gender {
  male('male'),
  female('female'),
  other('other');

  const Gender(this.apiValue);

  final String apiValue;

  static Gender? fromApi(String? value) =>
      values.where((v) => v.apiValue == value).firstOrNull;
}

enum TrainingGoal {
  strength('strength'),
  muscle('muscle'),
  fatLoss('fat_loss'),
  general('general');

  const TrainingGoal(this.apiValue);

  final String apiValue;

  static TrainingGoal? fromApi(String? value) =>
      values.where((v) => v.apiValue == value).firstOrNull;
}

enum ExperienceLevel {
  beginner('beginner'),
  intermediate('intermediate'),
  advanced('advanced');

  const ExperienceLevel(this.apiValue);

  final String apiValue;

  static ExperienceLevel? fromApi(String? value) =>
      values.where((v) => v.apiValue == value).firstOrNull;
}

// Zakresy zgodne z walidacją API (`PATCH /profile/me`).
const kMinUserAge = 16;
const kMaxUserAge = 100;
const kMinHeightCm = 100;
const kMaxHeightCm = 250;
const kMinWeightKg = 30.0;
const kMaxWeightKg = 300.0;
const kMaxWeeklyTrainingDays = 7;
const kHandleMinLength = 3;
const kHandleMaxLength = 30;
final kHandlePattern = RegExp(r'^[a-z0-9][a-z0-9._]{2,29}$');

/// Pełne lata między [birth] a [today] (liczą się tylko daty).
int fullYearsBetween(DateTime birth, DateTime today) {
  final beforeBirthday = today.month < birth.month ||
      (today.month == birth.month && today.day < birth.day);
  return today.year - birth.year - (beforeBirthday ? 1 : 0);
}

/// `YYYY-MM-DD` → lokalna data; `null` dla pustej lub błędnej wartości.
DateTime? parseIsoDate(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

String formatIsoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
