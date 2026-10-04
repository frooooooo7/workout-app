import 'package:flutter/material.dart';

import '../../../../core/units/weight_unit.dart';
import '../../../../core/utils/polish_plural.dart';
import '../../domain/models/profile_details.dart';

extension GenderLabel on Gender {
  String get label => switch (this) {
    Gender.male => 'Mężczyzna',
    Gender.female => 'Kobieta',
    Gender.other => 'Inna',
  };
}

extension TrainingGoalLabel on TrainingGoal {
  String get label => switch (this) {
    TrainingGoal.strength => 'Siła',
    TrainingGoal.muscle => 'Masa mięśniowa',
    TrainingGoal.fatLoss => 'Redukcja',
    TrainingGoal.general => 'Ogólna forma',
  };

  String get description => switch (this) {
    TrainingGoal.strength => 'Większe ciężary w głównych bojach',
    TrainingGoal.muscle => 'Budowa mięśni i sylwetki',
    TrainingGoal.fatLoss => 'Mniej tkanki tłuszczowej, siła zostaje',
    TrainingGoal.general => 'Zdrowie, sprawność i regularność',
  };

  IconData get icon => switch (this) {
    TrainingGoal.strength => Icons.fitness_center_rounded,
    TrainingGoal.muscle => Icons.accessibility_new_rounded,
    TrainingGoal.fatLoss => Icons.local_fire_department_rounded,
    TrainingGoal.general => Icons.favorite_border_rounded,
  };

  /// Ilustracja manekina 3D (w stylu ilustracji ćwiczeń); gdy pliku brak,
  /// karta pokazuje [icon].
  String get imageAsset => switch (this) {
    TrainingGoal.strength => 'assets/images/goal_strength.webp',
    TrainingGoal.muscle => 'assets/images/goal_muscle.webp',
    TrainingGoal.fatLoss => 'assets/images/goal_fat_loss.webp',
    TrainingGoal.general => 'assets/images/goal_general.webp',
  };
}

extension ExperienceLevelLabel on ExperienceLevel {
  String get label => switch (this) {
    ExperienceLevel.beginner => 'Początkujący',
    ExperienceLevel.intermediate => 'Średniozaawansowany',
    ExperienceLevel.advanced => 'Zaawansowany',
  };

  /// Do wąskich kafelków.
  String get shortLabel => switch (this) {
    ExperienceLevel.intermediate => 'Średni',
    _ => label,
  };

  /// 1–3 — liczba wypełnionych kresek poziomu.
  int get rank => index + 1;

  String get description => switch (this) {
    ExperienceLevel.beginner => 'Trenuję krócej niż rok',
    ExperienceLevel.intermediate => '1–3 lata regularnych treningów',
    ExperienceLevel.advanced => 'Ponad 3 lata, znam swoje maksy',
  };
}

const kPolishMonths = [
  'Styczeń',
  'Luty',
  'Marzec',
  'Kwiecień',
  'Maj',
  'Czerwiec',
  'Lipiec',
  'Sierpień',
  'Wrzesień',
  'Październik',
  'Listopad',
  'Grudzień',
];

const _polishMonthsGenitive = [
  'stycznia',
  'lutego',
  'marca',
  'kwietnia',
  'maja',
  'czerwca',
  'lipca',
  'sierpnia',
  'września',
  'października',
  'listopada',
  'grudnia',
];

/// `15 marca 1998`
String formatBirthDate(DateTime date) =>
    '${date.day} ${_polishMonthsGenitive[date.month - 1]} ${date.year}';

/// `28 lat`, `22 lata`
String formatAge(int years) =>
    '$years ${polishPlural(years, 'rok', 'lata', 'lat')}';

/// `182 cm`
String formatHeightCm(int cm) => '$cm cm';

/// Masa ciała: `82,5 kg`, `80 kg`, w funtach `182 lb`.
String formatWeightKg(double kg) =>
    '${formatWeightValue(kg)} ${WeightUnits.current.label}';

/// `82,5`, `80` — bez jednostki, w aktualnej jednostce. Funty bez ułamka:
/// masa ciała leży w bazie z dokładnością do 0,1 kg (~0,2 lb), więc wpisane
/// 180 lb wróciłoby jako 179,9.
String formatWeightValue(double kg) {
  final unit = WeightUnits.current;
  if (unit == WeightUnit.lb) return unit.fromKg(kg).round().toString();
  return kg == kg.roundToDouble()
      ? kg.toInt().toString()
      : kg.toStringAsFixed(1).replaceAll('.', ',');
}

/// Zakres masy ciała w jednostce [unit]. W funtach zaokrąglony do dziesiątek
/// do środka zakresu z API (30–300 kg), żeby linijka miała okrągłe podpisy.
({double min, double max}) bodyWeightRange(WeightUnit unit) {
  if (unit == WeightUnit.kg) return (min: kMinWeightKg, max: kMaxWeightKg);
  return (
    min: (unit.fromKg(kMinWeightKg) / 10).ceilToDouble() * 10,
    max: (unit.fromKg(kMaxWeightKg) / 10).floorToDouble() * 10,
  );
}

/// Dozwolony zakres masy ciała: `30–300 kg`, `70–660 lb`.
String formatWeightRange() {
  final unit = WeightUnits.current;
  final range = bodyWeightRange(unit);
  return '${range.min.toInt()}–${range.max.toInt()} ${unit.label}';
}

/// `4× w tygodniu`
String formatWeeklyTrainingDays(int days) => '$days× w tygodniu';

/// `4 treningi w tygodniu`, `1 trening w tygodniu`
String formatWeeklyTrainingsLong(int days) =>
    '$days ${polishPlural(days, 'trening', 'treningi', 'treningów')} '
    'w tygodniu';
