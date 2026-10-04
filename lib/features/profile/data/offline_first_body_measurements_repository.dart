import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../../core/network/api_client.dart';
import '../../library/data/exercise_database.dart';
import '../domain/models/body_measurement_entry.dart';
import '../domain/models/profile_details.dart';
import '../domain/repositories/body_measurements_repository.dart';
import 'sync/body_measurements_sync_engine.dart';

/// Dziennik pomiarów ciała w bazie konta: zapis i usunięcie działają
/// offline, a [BodyMeasurementsSyncEngine] wysyła je po powrocie sieci.
class OfflineFirstBodyMeasurementsRepository
    implements BodyMeasurementsRepository {
  OfflineFirstBodyMeasurementsRepository({
    required ExerciseDatabase localDb,
    required BodyMeasurementsSyncEngine syncEngine,
    DateTime Function() clock = DateTime.now,
  }) : _localDb = localDb,
       _sync = syncEngine,
       _clock = clock;

  final ExerciseDatabase _localDb;
  final BodyMeasurementsSyncEngine _sync;
  final DateTime Function() _clock;

  static const _table = ExerciseDatabase.tableBodyMeasurementEntries;

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
  Future<List<BodyMeasurementEntry>> list({int limit = 1000}) async {
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
        where: "pending_op IS NULL OR pending_op <> 'delete'",
        orderBy: 'date DESC',
        limit: limit,
      ),
    );
    _scheduleFlush();
    _schedulePull();
    return [
      for (final row in rows.reversed)
        ?BodyMeasurementsSyncEngine.entryFromRow(row),
    ];
  }

  @override
  Future<BodyMeasurementEntry> save(BodyMeasurementEntry entry) async {
    if (entry.values.isEmpty) {
      throw const ApiException('no_measurements', statusCode: 400);
    }
    for (final MapEntry(key: field, :value) in entry.values.entries) {
      if (!field.accepts(value)) {
        throw const ApiException('invalid_measurement', statusCode: 400);
      }
    }
    final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
    final now = _clock();
    // Serwer przyjmuje dzień „jutro” względem UTC — lokalnie wystarczy dziś.
    if (day.isAfter(DateTime(now.year, now.month, now.day))) {
      throw const ApiException('invalid_date', statusCode: 400);
    }
    final rounded = BodyMeasurementEntry(
      date: day,
      values: {
        for (final MapEntry(:key, :value) in entry.values.entries)
          key: (value * 10).round() / 10,
      },
    );
    await _localDb.run(
      (db) => db.insert(_table, {
        ...BodyMeasurementsSyncEngine.rowValues(rounded),
        'updated_at': now.toUtc().millisecondsSinceEpoch,
        'pending_op': 'upsert',
        // Nowa wersja od użytkownika — daj serwerowi kolejną szansę.
        'sync_error': null,
      }, conflictAlgorithm: ConflictAlgorithm.replace),
    );
    _scheduleFlush();
    return rounded;
  }

  @override
  Future<void> delete(DateTime date) async {
    final key = formatIsoDate(DateTime(date.year, date.month, date.day));
    await _localDb.run(
      (db) => db.insert(_table, {
        'date': key,
        'updated_at': _clock().toUtc().millisecondsSinceEpoch,
        'pending_op': 'delete',
        'sync_error': null,
      }, conflictAlgorithm: ConflictAlgorithm.replace),
    );
    _scheduleFlush();
  }
}
