import '../../library/data/exercise_database.dart';
import '../domain/models/training_session.dart';
import 'training_session_local_mapper.dart';

/// Odczyt zakończonych sesji z lokalnej bazy na potrzeby historii — żeby
/// trening zrobiony bez internetu był widoczny od razu, a nie dopiero po
/// synchronizacji i odświeżeniu historii z serwera.
class TrainingSessionLocalHistory {
  const TrainingSessionLocalHistory(this._localDb);

  final ExerciseDatabase _localDb;

  /// Górny limit wczytywanych sesji — lokalna baza trzyma też historię
  /// pobraną z serwera, a nie chcemy mapować całych lat przy każdej liście.
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
      // Sesje czekające na usunięcie znikają od razu, zanim serwer to
      // potwierdzi.
      final where = <String>[
        'status <> ?',
        "(pending_op IS NULL OR pending_op <> 'delete')",
      ];
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
      where.add(
        'EXISTS ('
        'SELECT 1 FROM ${ExerciseDatabase.tableTrainingSessionExercises} e '
        'WHERE e.session_local_id = ${ExerciseDatabase.tableTrainingSessions}.local_id'
        ')',
      );

      final rows = await db.query(
        ExerciseDatabase.tableTrainingSessions,
        where: where.join(' AND '),
        whereArgs: args,
        orderBy: 'started_at DESC',
        limit: _maxSessions,
      );
      return TrainingSessionLocalMapper.fromDbMany(db, rows);
    });
  }

  /// Szuka po `local_id` albo `server_id` (bez sesji czekających na
  /// usunięcie).
  Future<TrainingSession?> findById(String id) {
    return _localDb.run((db) async {
      final rows = await db.query(
        ExerciseDatabase.tableTrainingSessions,
        where:
            "(local_id = ? OR server_id = ?) "
            "AND (pending_op IS NULL OR pending_op <> 'delete')",
        whereArgs: [id, id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return TrainingSessionLocalMapper.fromDb(db, rows.first);
    });
  }

  /// Id (lokalne i serwerowe) sesji usuniętych na tym urządzeniu, których
  /// usunięcie nie dotarło jeszcze na serwer — historia serwera i cache
  /// muszą je ukrywać.
  Future<Set<String>> pendingDeletionIds() {
    return _localDb.run((db) async {
      final rows = await db.query(
        ExerciseDatabase.tableTrainingSessions,
        columns: ['local_id', 'server_id'],
        where: "pending_op = 'delete'",
      );
      return <String>{
        for (final row in rows) ...[
          row['local_id'] as String,
          if (row['server_id'] != null) row['server_id'] as String,
        ],
      };
    });
  }
}
