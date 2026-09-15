import '../domain/models/training_session.dart';
import '../domain/repositories/training_stats_repository.dart';
import 'training_session_local_history.dart';

/// Statystyki z lokalnej bazy (offline-first): sesje ukończone na tym
/// urządzeniu, zsynchronizowane i niewysłane.
class LocalTrainingStatsRepository implements TrainingStatsRepository {
  const LocalTrainingStatsRepository(this._localHistory);

  final TrainingSessionLocalHistory _localHistory;

  @override
  Future<List<TrainingSession>> completedSessionsSince(DateTime from) {
    return _localHistory.finishedSessions(
      status: TrainingSessionStatus.completed,
      from: from,
      includeSynced: true,
    );
  }
}
