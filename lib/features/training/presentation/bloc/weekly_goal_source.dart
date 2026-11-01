import 'dart:async';

import '../../../../core/services/service_locator.dart';

/// Cel „ile razy w tygodniu” z profilu użytkownika. Czyta lokalną kopię
/// profilu, więc karta celu jest od razu, także bez internetu; świeży profil
/// z serwera odświeża kopię w tle (przy następnym wejściu). Bez kopii
/// i sieci (albo bez celu w profilu) statystyki pomijają kartę celu.
Future<int?> loadOwnWeeklyGoal() async {
  final repository = ServiceLocator.profileRepository;
  final cached = await repository.cachedOwnProfile();
  if (cached != null) {
    unawaited(repository.getOwnProfile().then<void>((_) {}, onError: (_) {}));
    return cached.details?.weeklyTrainingDays;
  }
  final profile = await repository.getOwnProfile();
  return profile.details?.weeklyTrainingDays;
}
