import '../models/body_measurement_entry.dart';

/// Prywatny dziennik pomiarów ciała (`/profile/me/body-measurements`).
/// W aplikacji offline-first — zapis trafia do bazy konta i wysyła się po
/// powrocie sieci.
abstract class BodyMeasurementsRepository {
  /// Najnowsze [limit] wpisów, od najstarszego.
  Future<List<BodyMeasurementEntry>> list({int limit = 1000});

  /// Tworzy albo zastępuje cały wpis z dnia `entry.date`.
  Future<BodyMeasurementEntry> save(BodyMeasurementEntry entry);

  /// Usuwa wpis z dnia [date]; brak wpisu (404) też jest sukcesem.
  Future<void> delete(DateTime date);
}
