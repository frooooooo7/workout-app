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
}

extension ExperienceLevelLabel on ExperienceLevel {
  String get label => switch (this) {
        ExperienceLevel.beginner => 'Początkujący',
        ExperienceLevel.intermediate => 'Średniozaawansowany',
        ExperienceLevel.advanced => 'Zaawansowany',
      };

  String get description => switch (this) {
        ExperienceLevel.beginner => 'Trenuję krócej niż rok',
        ExperienceLevel.intermediate => '1–3 lata regularnych treningów',
        ExperienceLevel.advanced => 'Ponad 3 lata, znam swoje maksy',
      };
}

/// `15.03.1998`
String formatBirthDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.'
    '${date.month.toString().padLeft(2, '0')}.'
    '${date.year.toString().padLeft(4, '0')}';

/// `28 lat`, `22 lata`
String formatAge(int years) =>
    '$years ${polishPlural(years, 'rok', 'lata', 'lat')}';

/// `182 cm`
String formatHeightCm(int cm) => '$cm cm';

/// `82,5 kg`, `80 kg`
String formatWeightKg(double kg) {
  final text = kg == kg.roundToDouble()
      ? kg.toInt().toString()
      : kg.toStringAsFixed(1).replaceAll('.', ',');
  return '$text kg';
}

/// `4× w tygodniu`
String formatWeeklyTrainingDays(int days) => '$days× w tygodniu';
