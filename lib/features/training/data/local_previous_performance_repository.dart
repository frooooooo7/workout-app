import '../../library/data/exercise_database.dart';
import '../domain/models/training_session.dart';
import '../domain/repositories/previous_performance_repository.dart';
import 'training_session_local_mapper.dart';

/// „Poprzednio” z lokalnej bazy — działa offline i obejmuje też treningi
/// pobrane z serwera. Dwa zapytania na ćwiczenie, bez mapowania całych sesji.
class LocalPreviousPerformanceRepository
    implements PreviousPerformanceRepository {
  const LocalPreviousPerformanceRepository(this._localDb);

  final ExerciseDatabase _localDb;

  @override
  Future<List<TrainingSessionSet>?> lastCompletedSets({
    required String exerciseId,
    required String exerciseName,
  }) {
    return _localDb.run((db) async {
      // Po identyfikatorze, a gdy go brak — po nazwie (bez rozróżniania
      // wielkości liter ASCII; SQLite nie zna wielkich liter spoza ASCII).
      final latest = await db.rawQuery(
        '''
        SELECT e.local_id AS exercise_row_id
        FROM ${ExerciseDatabase.tableTrainingSessionExercises} e
        JOIN ${ExerciseDatabase.tableTrainingSessions} s
          ON s.local_id = e.session_local_id
        WHERE s.status = ?
          AND (s.pending_op IS NULL OR s.pending_op <> 'delete')
          AND ((? <> '' AND e.exercise_local_id = ?)
               OR e.exercise_name = ? COLLATE NOCASE)
          AND EXISTS (
            SELECT 1 FROM ${ExerciseDatabase.tableTrainingSessionSets} t
            WHERE t.session_exercise_local_id = e.local_id
              AND t.completed = 1
              AND t.set_type <> 'warmup'
          )
        ORDER BY s.started_at DESC
        LIMIT 1
        ''',
        [
          TrainingSessionStatus.completed.name,
          exerciseId,
          exerciseId,
          exerciseName.trim(),
        ],
      );
      if (latest.isEmpty) return null;

      final rows = await db.query(
        ExerciseDatabase.tableTrainingSessionSets,
        where: 'session_exercise_local_id = ? AND completed = 1',
        whereArgs: [latest.first['exercise_row_id']],
        orderBy: 'position ASC',
      );
      return [
        for (final row in rows) TrainingSessionLocalMapper.setFromRow(row),
      ];
    });
  }
}
