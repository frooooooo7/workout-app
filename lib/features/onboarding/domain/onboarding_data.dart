enum Gender { male, female, notSpecified }

enum ActivityLevel { sedentary, light, moderate, active }

enum FitnessGoal { buildMuscle, loseWeight, getStronger, improveEndurance, stayHealthy }

final class OnboardingData {
  OnboardingData({
    this.gender,
    this.age,
    this.heightCm,
    this.weightKg,
    this.useMetricHeight = true,
    this.useMetricWeight = true,
    this.activityLevel,
    this.fitnessGoal,
    this.trainingDays = const {},
  });

  final Gender? gender;
  final int? age;
  final double? heightCm;
  final double? weightKg;
  final bool useMetricHeight;
  final bool useMetricWeight;
  final ActivityLevel? activityLevel;
  final FitnessGoal? fitnessGoal;
  final Set<int> trainingDays; // 0 = Mon … 6 = Sun

  OnboardingData copyWith({
    Gender? gender,
    int? age,
    double? heightCm,
    double? weightKg,
    bool? useMetricHeight,
    bool? useMetricWeight,
    ActivityLevel? activityLevel,
    FitnessGoal? fitnessGoal,
    Set<int>? trainingDays,
  }) {
    return OnboardingData(
      gender: gender ?? this.gender,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      useMetricHeight: useMetricHeight ?? this.useMetricHeight,
      useMetricWeight: useMetricWeight ?? this.useMetricWeight,
      activityLevel: activityLevel ?? this.activityLevel,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      trainingDays: trainingDays ?? this.trainingDays,
    );
  }
}
