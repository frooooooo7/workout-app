import 'package:flutter/material.dart';

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

/// `82,5 kg`, `80 kg`
String formatWeightKg(double kg) => '${formatWeightValue(kg)} kg';

/// `82,5`, `80` — bez jednostki.
String formatWeightValue(double kg) => kg == kg.roundToDouble()
    ? kg.toInt().toString()
    : kg.toStringAsFixed(1).replaceAll('.', ',');

/// `4× w tygodniu`
String formatWeeklyTrainingDays(int days) => '$days× w tygodniu';

/// `4 treningi w tygodniu`, `1 trening w tygodniu`
String formatWeeklyTrainingsLong(int days) =>
    '$days ${polishPlural(days, 'trening', 'treningi', 'treningów')} '
    'w tygodniu';
