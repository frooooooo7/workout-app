import '../../../../core/services/service_locator.dart';

/// Cel „ile razy w tygodniu” z profilu użytkownika. Wymaga sieci — bez niej
/// (albo bez celu w profilu) statystyki po prostu pomijają kartę celu.
Future<int?> loadOwnWeeklyGoal() async {
  final profile = await ServiceLocator.profileRepository.getOwnProfile();
  return profile.details?.weeklyTrainingDays;
}
