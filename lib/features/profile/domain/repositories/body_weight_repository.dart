import '../models/body_weight_entry.dart';

/// Prywatny dziennik masy ciała (`/profile/me/body-weight`). W aplikacji
/// offline-first — zapis trafia do bazy konta i wysyła się po powrocie sieci.
abstract class BodyWeightRepository {
  /// Najnowsze [limit] pomiarów, od najstarszego.
  Future<List<BodyWeightEntry>> list({int limit = 1000});

  /// Tworzy albo zastępuje pomiar z dnia [date]. Najnowszy pomiar staje się
  /// też aktualną wagą w „Dane i cele”.
  Future<BodyWeightEntry> save(DateTime date, double weightKg);

  /// Usuwa pomiar z dnia [date]; brak pomiaru (404) też jest sukcesem.
  Future<void> delete(DateTime date);
}

/// Po zmianie wagi w „Dane i cele” albo w onboardingu dopisuje dzisiejszy
/// pomiar, żeby historia zgadzała się z aktualną wagą. Błąd tylko pomija
/// pomiar — sama waga w profilu jest już zapisana.
Future<void> logProfileWeightChange(
  BodyWeightRepository? repository, {
  required double? previous,
  required double? current,
  DateTime Function() clock = DateTime.now,
}) async {
  if (repository == null || current == null || current == previous) return;
  final now = clock();
  try {
    await repository.save(DateTime(now.year, now.month, now.day), current);
  } catch (_) {
    /* pomiar jest dodatkiem do zapisu profilu */
  }
}
