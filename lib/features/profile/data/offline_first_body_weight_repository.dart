import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../../core/network/api_client.dart';
import '../../library/data/exercise_database.dart';
import '../domain/models/body_weight_entry.dart';
import '../domain/models/profile_details.dart';
import '../domain/repositories/body_weight_repository.dart';
import 'sync/body_weight_sync_engine.dart';

/// Dziennik masy ciała w bazie konta: zapis i usunięcie działają offline,
/// a [BodyWeightSyncEngine] wysyła je po powrocie sieci.
class OfflineFirstBodyWeightRepository implements BodyWeightRepository {
  OfflineFirstBodyWeightRepository({
    required ExerciseDatabase localDb,
    required BodyWeightSyncEngine syncEngine,
    DateTime Function() clock = DateTime.now,
  }) : _localDb = localDb,
       _sync = syncEngine,
       _clock = clock;

  final ExerciseDatabase _localDb;
  final BodyWeightSyncEngine _sync;
  final DateTime Function() _clock;

  static const _table = ExerciseDatabase.tableBodyWeightEntries;

  // Te same granice co walidacja na serwerze — pomiar, który i tak zostałby
  // odrzucony, nie trafia do kolejki.
  static const minWeightKg = 30.0;
  static const maxWeightKg = 300.0;

  void _scheduleFlush() {
    if (_sync.isStopped) return;
    unawaited(
      _sync.flush().catchError((_) {
        /* background sync must never break the UI event loop */
      }),
    );
  }

  void _schedulePull() {
    if (_sync.isStopped) return;
    unawaited(
      _sync.pullIfDue().catchError((_) {
        /* background sync must never break the UI event loop */
      }),
    );
  }

  @override
  Future<List<BodyWeightEntry>> list({int limit = 1000}) async {
    if (!_sync.isStopped) {
      try {
        await _sync.ensureInitialPull();
      } catch (_) {
        /* offline — pokazujemy to, co jest lokalnie */
      }
    }
    final rows = await _localDb.run(
      (db) => db.query(
        _table,
        columns: ['date', 'weight_kg'],
        where: "pending_op IS NULL OR pending_op <> 'delete'",
        orderBy: 'date DESC',
        limit: limit,
      ),
    );
    _scheduleFlush();
    _schedulePull();
    return [
      for (final row in rows.reversed)
        if (parseIsoDate(row['date'] as String) case final date?)
          BodyWeightEntry(
            date: date,
            weightKg: (row['weight_kg'] as num).toDouble(),
          ),
    ];
  }

  @override
  Future<BodyWeightEntry> save(DateTime date, double weightKg) async {
    if (weightKg < minWeightKg || weightKg > maxWeightKg) {
      throw const ApiException('invalid_weight', statusCode: 400);
    }
    final day = DateTime(date.year, date.month, date.day);
    final now = _clock();
    // Serwer przyjmuje dzień „jutro” względem UTC — lokalnie wystarczy dziś.
    if (day.isAfter(DateTime(now.year, now.month, now.day))) {
      throw const ApiException('invalid_date', statusCode: 400);
    }
    final entry = BodyWeightEntry(
      date: day,
      weightKg: (weightKg * 10).round() / 10,
    );
    await _localDb.run(
      (db) => db.insert(_table, {
        'date': formatIsoDate(day),
        'weight_kg': entry.weightKg,
        'updated_at': now.toUtc().millisecondsSinceEpoch,
        'pending_op': 'upsert',
        // Nowa wersja od użytkownika — daj serwerowi kolejną szansę.
        'sync_error': null,
      }, conflictAlgorithm: ConflictAlgorithm.replace),
    );
    _scheduleFlush();
    return entry;
  }

  @override
  Future<void> delete(DateTime date) async {
    final key = formatIsoDate(DateTime(date.year, date.month, date.day));
    await _localDb.run(
      (db) => db.insert(_table, {
        'date': key,
        'weight_kg': 0,
        'updated_at': _clock().toUtc().millisecondsSinceEpoch,
        'pending_op': 'delete',
        'sync_error': null,
      }, conflictAlgorithm: ConflictAlgorithm.replace),
    );
    _scheduleFlush();
  }
}
