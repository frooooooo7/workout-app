import 'package:flutter/foundation.dart';

import '../domain/models/training_session.dart';
import '../domain/repositories/training_stats_repository.dart';
import 'training_session_local_history.dart';

/// Statystyki z lokalnej bazy (offline-first): sesje z tego urządzenia
/// (także niewysłane) i historia pobrana z serwera przez synchronizację sesji.
class LocalTrainingStatsRepository implements TrainingStatsRepository {
  const LocalTrainingStatsRepository(this._localHistory, {this.onRead});

  final TrainingSessionLocalHistory _localHistory;

  /// Wołane przy każdym odczycie — np. `pullIfDue` synchronizacji sesji, żeby
  /// treningi z innych urządzeń dotarły do statystyk (wynik przychodzi
  /// sygnałem zmiany danych).
  final VoidCallback? onRead;

  @override
  Future<List<TrainingSession>> completedSessionsSince(DateTime from) {
    onRead?.call();
    return _localHistory.finishedSessions(
      status: TrainingSessionStatus.completed,
      from: from,
      includeSynced: true,
    );
  }
}
