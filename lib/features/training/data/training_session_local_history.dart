import '../../library/data/exercise_database.dart';
import '../domain/models/training_session.dart';
import 'training_session_local_mapper.dart';

/// Odczyt zakończonych sesji z lokalnej bazy na potrzeby historii — żeby
/// trening zrobiony bez internetu był widoczny od razu, a nie dopiero po
/// synchronizacji i odświeżeniu historii z serwera.
class TrainingSessionLocalHistory {
  const TrainingSessionLocalHistory(this._localDb);

  final ExerciseDatabase _localDb;

  /// Górny limit wczytywanych sesji — lokalna baza trzyma tylko treningi
  /// z tego urządzenia, ale nie chcemy mapować całego roku przy każdej liście.
  static const _maxSessions = 100;

  /// Zakończone (lub anulowane) sesje z ćwiczeniami, najnowsze najpierw.
  ///
  /// [includeSynced] = `false` zwraca tylko sesje, których serwer jeszcze
  /// nie potwierdził — pozostałe są już w odpowiedzi API.
  Future<List<TrainingSession>> finishedSessions({
    TrainingSessionStatus? status,
    DateTime? from,
    DateTime? to,
    required bool includeSynced,
  }) {
    return _localDb.run((db) async {
      final where = <String>['status <> ?'];
      final args = <Object?>[TrainingSessionStatus.active.name];
      if (status != null) {
        where.add('status = ?');
        args.add(status.name);
      }
      if (from != null) {
        where.add('started_at >= ?');
        args.add(from.toUtc().millisecondsSinceEpoch);
      }
      if (to != null) {
        where.add('started_at <= ?');
        args.add(to.toUtc().millisecondsSinceEpoch);
      }
      if (!includeSynced) {
        where.add('(pending_op IS NOT NULL OR server_id IS NULL)');
      }

      final rows = await db.query(
        ExerciseDatabase.tableTrainingSessions,
        where: where.join(' AND '),
        whereArgs: args,
        orderBy: 'started_at DESC',
        limit: _maxSessions,
      );
      final sessions = <TrainingSession>[];
      for (final row in rows) {
        final session = await TrainingSessionLocalMapper.fromDb(db, row);
        if (session != null && session.exercises.isNotEmpty) {
          sessions.add(session);
        }
      }
      return sessions;
    });
  }

  /// Szuka po `local_id` albo `server_id`.
  Future<TrainingSession?> findById(String id) {
    return _localDb.run((db) async {
      final rows = await db.query(
        ExerciseDatabase.tableTrainingSessions,
        where: 'local_id = ? OR server_id = ?',
        whereArgs: [id, id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return TrainingSessionLocalMapper.fromDb(db, rows.first);
    });
  }
}
