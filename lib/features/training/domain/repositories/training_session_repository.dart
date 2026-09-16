import '../models/custom_training_plan.dart';
import '../models/training_session.dart';

/// Sesja została usunięta (lokalnie albo na serwerze — `410 session_deleted`)
/// i nie da się już jej zmienić.
class TrainingSessionDeletedException implements Exception {
  const TrainingSessionDeletedException(this.sessionId);

  final String sessionId;

  @override
  String toString() => 'TrainingSessionDeletedException(sessionId: $sessionId)';
}

abstract interface class TrainingSessionRepository {
  Future<TrainingSession?> getActive();

  /// Szuka po `local_id` albo `server_id` — historia podaje ten drugi.
  /// Sesje czekające na usunięcie są pomijane.
  Future<TrainingSession?> getById(String sessionId);

  Future<TrainingSession> startFromPlan(CustomTrainingPlan plan);

  Future<TrainingSession> startCustom({
    String planName = TrainingSession.defaultCustomName,
  });

  /// Nowa aktywna sesja wypełniona na podstawie [source] („Powtórz trening”).
  /// Rzuca `ActiveTrainingSessionException`, gdy trwa już inny trening.
  Future<TrainingSession> startFromSession(TrainingSession source);

  Future<TrainingSession> save(TrainingSession session);

  Future<TrainingSession> finish(String sessionId);

  Future<TrainingSession> cancel(String sessionId);

  /// Włącza/wyłącza widoczność ukończonej sesji w aktywności na profilu.
  Future<TrainingSession> setSharedToProfile(String sessionId, bool shared);

  /// Sesja do edycji/powtórzenia: z lokalnej bazy, a gdy jej tam nie ma
  /// (np. z innego urządzenia) — pobrana z serwera i zapisana lokalnie.
  /// `null`, gdy nie udało się jej znaleźć (np. offline).
  Future<TrainingSession?> loadForEdit(String sessionId);

  /// Usuwa zakończoną sesję (offline-first). Działa także dla sesji znanych
  /// tylko z historii serwera.
  Future<void> delete(String sessionId);
}
