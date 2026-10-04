import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/sync/sync_engine_base.dart';
import '../../../../core/sync/sync_failure.dart';
import '../../../library/data/exercise_database.dart';
import '../../domain/models/body_measurement_entry.dart';
import '../../domain/models/profile_details.dart';
import '../../domain/repositories/body_measurements_repository.dart';

/// Synchronizacja dziennika pomiarów ciała — jak `BodyWeightSyncEngine`:
/// kluczem jest dzień, a `PUT` (całego wpisu) i `DELETE` są idempotentne,
/// więc wysyłka powtarza ostatnią wersję dnia.
class BodyMeasurementsSyncEngine extends SyncEngineBase {
  BodyMeasurementsSyncEngine({
    required BodyMeasurementsRepository remote,
    required ExerciseDatabase localDb,
    super.onDataChanged,
  }) : _remote = remote,
       _localDb = localDb;

  final BodyMeasurementsRepository _remote;
  final ExerciseDatabase _localDb;

  static const _table = ExerciseDatabase.tableBodyMeasurementEntries;

  /// Klucz [ExerciseDatabase.tableSyncState]: czas pierwszego udanego pobrania.
  static const pulledAtKey = 'body_measurements_pulled_at';

  /// Maksimum `limit` w `GET /profile/me/body-measurements`.
  static const pullLimit = 1000;

  /// Kolumny wpisu (bez stanu synchronizacji).
  static Map<String, Object?> rowValues(BodyMeasurementEntry entry) => {
    'date': formatIsoDate(entry.date),
    for (final field in BodyMeasurementField.values) field.column: entry[field],
  };

  /// Wpis z wiersza lokalnej tabeli; `null` dla uszkodzonego wiersza.
  static BodyMeasurementEntry? entryFromRow(Map<String, Object?> row) {
    final date = parseIsoDate(row['date'] as String?);
    if (date == null) return null;
    return BodyMeasurementEntry(
      date: date,
      values: {
        for (final field in BodyMeasurementField.values)
          if (row[field.column] case final num value) field: value.toDouble(),
      },
    );
  }

  Future<void> flush() => runCoalesced('flush', _flushImpl);

  Future<void> pull() => runCoalesced('pull', _pullImpl);

  Future<void> pullIfDue({Duration maxAge = SyncEngineBase.defaultPullMaxAge}) {
    return runCoalesced('pull-if-due', () async {
      if (isPullDue(maxAge)) await _pullImpl();
    });
  }

  /// Przed pierwszym pobraniem lokalna tabela jest pusta — ekran poczeka na
  /// serwer zamiast pokazać pusty dziennik. Offline czeka tylko na jedną
  /// próbę na [maxAge].
  Future<void> ensureInitialPull({
    Duration maxAge = SyncEngineBase.defaultPullMaxAge,
  }) {
    return runCoalesced('initial-pull', () async {
      if (!isPullDue(maxAge)) return;
      if (await _localDb.readSyncState(pulledAtKey) != null) return;
      await _pullImpl();
    });
  }

  static String _attemptKey(String date) => 'body_measurements:$date';

  Future<void> _handleFailure(
    String date,
    String op,
    ApiException error,
  ) async {
    await _localDb.recordSyncAttemptFailure(
      localId: _attemptKey(date),
      op: '${op}_body_measurements',
      message: error.message,
    );
    if (registerFailure(error) == SyncFailureKind.permanent) {
      await _localDb.run(
        (db) => db.update(
          _table,
          {'sync_error': error.message},
          where: 'date = ?',
          whereArgs: [date],
        ),
      );
    }
  }

  // ── Flush ─────────────────────────────────────────────────────────────────

  Future<void> _flushImpl() async {
    if (isStopped) return;
    final List<Map<String, Object?>> rows;
    try {
      rows = await _localDb.run(
        (db) => db.query(
          _table,
          where: 'pending_op IS NOT NULL AND sync_error IS NULL',
          orderBy: 'date ASC',
        ),
      );
    } on StateError {
      return; /* DB closing */
    }
    if (rows.isEmpty) return;

    final networkMark = networkFailureMark;
    var uploaded = false;
    for (final row in rows) {
      if (isStopped) return;
      final date = row['date'] as String;
      try {
        if (await _flushRow(row)) uploaded = true;
      } on StateError {
        return; /* DB closing */
      } catch (error, stackTrace) {
        // Jeden uszkodzony wiersz nie może zablokować wysyłki pozostałych.
        logUnexpected('Body measurements $date sync failed', error, stackTrace);
      }
      if (networkFailedSince(networkMark)) break;
    }
    if (uploaded) notifyDataChanged();
  }

  Future<bool> _flushRow(Map<String, Object?> row) async {
    final date = row['date'] as String;
    final op = row['pending_op'] as String;
    final updatedAt = row['updated_at'] as int;
    final entry = entryFromRow(row);
    if (entry == null) {
      throw FormatException('Invalid body measurements date: $date');
    }

    if (op == 'delete') {
      try {
        await _remote.delete(entry.date);
      } on ApiException catch (e) {
        await _handleFailure(date, op, e);
        return false;
      }
      // Nowy wpis z tego dnia w trakcie żądania zostaje w kolejce.
      await _localDb.run(
        (db) => db.delete(
          _table,
          where: "date = ? AND updated_at = ? AND pending_op = 'delete'",
          whereArgs: [date, updatedAt],
        ),
      );
    } else {
      final BodyMeasurementEntry saved;
      try {
        saved = await _remote.save(entry);
      } on ApiException catch (e) {
        await _handleFailure(date, op, e);
        return false;
      }
      // Serwer zaokrągla wartości; edycja w trakcie żądania wyśle się jeszcze
      // raz.
      await _localDb.run(
        (db) => db.update(
          _table,
          {...rowValues(saved), 'pending_op': null, 'sync_error': null},
          where: 'date = ? AND updated_at = ?',
          whereArgs: [date, updatedAt],
        ),
      );
    }
    await _localDb.clearSyncAttempts(_attemptKey(date));
    return true;
  }

  // ── Pull ──────────────────────────────────────────────────────────────────

  Future<void> _pullImpl() async {
    if (isStopped) return;
    markPullAttempt();
    try {
      final entries = await _remote.list(limit: pullLimit);
      if (isStopped) return;
      final changed = await _localDb.run(
        (db) => db.transaction((txn) => _storePulled(txn, entries)),
      );
      await _localDb.writeSyncState(
        pulledAtKey,
        DateTime.now().toUtc().toIso8601String(),
      );
      if (changed) notifyDataChanged();
    } on ApiException catch (e) {
      registerFailure(e);
    } on StateError {
      /* DB closing */
    }
  }

  /// Zastępuje lokalne wpisy wersją z serwera. Wiersze z niewysłanymi
  /// zmianami zostają nietknięte. Zwraca, czy coś się zmieniło.
  Future<bool> _storePulled(
    Transaction txn,
    List<BodyMeasurementEntry> entries,
  ) async {
    final local = {
      for (final row in await txn.query(_table)) row['date'] as String: row,
    };
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    var changed = false;

    final serverDates = <String>{};
    for (final entry in entries) {
      final date = formatIsoDate(entry.date);
      serverDates.add(date);
      final existing = local[date];
      if (existing != null) {
        if (existing['pending_op'] != null) continue;
        if (entryFromRow(existing) == entry) continue;
      }
      await txn.insert(_table, {
        ...rowValues(entry),
        'updated_at': now,
        'pending_op': null,
        'sync_error': null,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      changed = true;
    }

    // Pełna lista — brak dnia na serwerze to usunięcie na innym urządzeniu.
    // Przy obciętej liście nie wiadomo nic o dniach starszych niż najstarszy
    // zwrócony, więc je zostawiamy.
    final truncated = entries.length >= pullLimit;
    final oldest = entries.isEmpty ? null : formatIsoDate(entries.first.date);
    final removed = <String>[
      for (final MapEntry(key: date, value: row) in local.entries)
        if (row['pending_op'] == null &&
            !serverDates.contains(date) &&
            (!truncated || oldest == null || date.compareTo(oldest) >= 0))
          date,
    ];
    for (final date in removed) {
      await txn.delete(_table, where: 'date = ?', whereArgs: [date]);
      changed = true;
    }
    return changed;
  }
}
