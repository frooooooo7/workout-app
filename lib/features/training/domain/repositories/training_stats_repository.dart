import '../models/training_session.dart';

/// Źródło danych do podsumowania treningów (tydzień / miesiąc).
abstract interface class TrainingStatsRepository {
  /// Ukończone sesje rozpoczęte od [from] (włącznie), z ćwiczeniami
  /// i seriami — także te jeszcze niewysłane na serwer.
  Future<List<TrainingSession>> completedSessionsSince(DateTime from);
}
